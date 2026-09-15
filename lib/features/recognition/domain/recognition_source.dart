import 'dart:typed_data';

sealed class RecognitionSource {
  const RecognitionSource();
}

final class PhotoSource extends RecognitionSource {
  const PhotoSource(this.filePath);
  final String filePath;
}

final class DrawingSource extends RecognitionSource {
  const DrawingSource(this.bytes);
  final Uint8List bytes;
}