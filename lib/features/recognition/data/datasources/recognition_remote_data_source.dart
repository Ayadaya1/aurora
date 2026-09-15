import 'dart:convert';

import 'package:aurora/core/error/failure.dart';
import 'package:aurora/features/recognition/domain/recognition_source.dart';
import 'package:dio/dio.dart';

abstract interface class RecognitionRemoteDataSource {
  Future<String> recognize(RecognitionSource source);
}

class DioRecognitionRemoteDataSource implements RecognitionRemoteDataSource {
  DioRecognitionRemoteDataSource({required Dio dio, required String baseUrl})
    : _dio = dio,
      _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  @override
  Future<String> recognize(RecognitionSource source) async {
    final formData = FormData();

    switch (source) {
      case PhotoSource(:final filePath):
        formData.fields.add(const MapEntry('mode', 'photo'));
        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(filePath, filename: 'formula.jpg'),
          ),
        );
      case DrawingSource(:final bytes):
        formData.fields.add(const MapEntry('mode', 'drawing'));
        formData.files.add(
          MapEntry(
            'image',
            MultipartFile.fromBytes(bytes, filename: 'drawing.png'),
          ),
        );
    }

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/recognize',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final raw = response.data;
      final Map<String, dynamic> json = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : raw as Map<String, dynamic>;

      final latex = json['latex']?.toString();
      if (latex == null || latex.isEmpty) {
        throw const ServerFailure('Сервер не вернул LaTeX');
      }
      return latex;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map
          ? (data['detail'] ?? data['message'] ?? e.message).toString()
          : (data?.toString() ?? e.message ?? 'Ошибка соединения');
      throw NetworkFailure(message);
    }
  }
}
