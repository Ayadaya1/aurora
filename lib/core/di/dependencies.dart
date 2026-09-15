import 'package:aurora/core/config/app_config.dart';
import 'package:aurora/features/recognition/data/datasources/recognition_remote_data_source.dart';
import 'package:aurora/features/recognition/data/repositories/recognition_repository_impl.dart';
import 'package:aurora/features/recognition/domain/use_cases/recognize_formula.dart';
import 'package:dio/dio.dart';

abstract final class Dependencies {
  static late final RecognizeFormula recognizeFormula;

  static void init() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ));

    final remote = DioRecognitionRemoteDataSource(
      dio: dio,
      baseUrl: AppConfig.apiBaseUrl,
    );

    recognizeFormula = RecognizeFormula(
      RecognitionRepositoryImpl(remote),
    );
  }
}