import 'package:aurora/core/error/failure.dart';
import 'package:aurora/features/recognition/domain/recognition_source.dart';
import 'package:aurora/features/recognition/domain/use_cases/recognize_formula.dart';
import 'package:flutter/foundation.dart';

enum RecognitionMode { photo, drawing }

class RecognitionController extends ChangeNotifier {
  RecognitionController({required RecognizeFormula recognizeFormula})
    : _recognizeFormula = recognizeFormula;

  final RecognizeFormula _recognizeFormula;

  RecognitionMode _mode = RecognitionMode.photo;

  RecognitionMode get mode => _mode;

  String? _photoPath;

  String? get photoPath => _photoPath;

  String? _latex;

  String? get latex => _latex;

  bool _isRecognizing = false;

  bool get isRecognizing => _isRecognizing;

  void setMode(RecognitionMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _photoPath = null;
    _latex = null;
    notifyListeners();
  }

  void setPhoto(String? path) {
    _photoPath = path;
    notifyListeners();
  }

  void clearResult() {
    if (_latex == null) return;
    _latex = null;
    notifyListeners();
  }

  Future<void> recognize(RecognitionSource source) async {
    if (_isRecognizing) return;

    _isRecognizing = true;
    _latex = null;
    notifyListeners();

    try {
      _latex = await _recognizeFormula(source);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw ServerFailure(e.toString());
    } finally {
      _isRecognizing = false;
      notifyListeners();
    }
  }
}
