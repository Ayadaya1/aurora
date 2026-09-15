import 'package:aurora/features/recognition/domain/recognition_source.dart';

import '../../domain/recognition_repository.dart' show RecognitionRepository;
import '../datasources/recognition_remote_data_source.dart';

class RecognitionRepositoryImpl implements RecognitionRepository {
  const RecognitionRepositoryImpl(this._remote);

  final RecognitionRemoteDataSource _remote;

  @override
  Future<String> recognize(RecognitionSource source) =>
      _remote.recognize(source);
}
