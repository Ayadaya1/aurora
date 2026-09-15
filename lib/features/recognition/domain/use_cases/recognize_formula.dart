import 'package:aurora/features/recognition/domain/recognition_repository.dart';
import 'package:aurora/features/recognition/domain/recognition_source.dart';

class RecognizeFormula {
  const RecognizeFormula(this._repository);

  final RecognitionRepository _repository;

  Future<String> call(RecognitionSource source) =>
      _repository.recognize(source);
}
