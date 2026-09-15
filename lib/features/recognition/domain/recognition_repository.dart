import 'package:aurora/features/recognition/domain/recognition_source.dart';

abstract interface class RecognitionRepository {
  Future<String> recognize(RecognitionSource source);
}
