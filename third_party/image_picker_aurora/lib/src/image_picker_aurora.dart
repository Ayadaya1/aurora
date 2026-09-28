// SPDX-FileCopyrightText: Copyright 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-FileCopyrightText: Copyright 2013 The Flutter Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:file_selector/file_selector.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'aurora_image_picker_delegate.dart';
import 'camera_dialog.dart';

void openCameraDialogImpl() {
  cameraDialogMain();
}

/// The Aurora implementation of [ImagePickerPlatform].
///
/// This class implements the `package:image_picker` functionality for
/// Aurora.
class ImagePickerAurora extends CameraDelegatingImagePickerPlatform {
  /// Constructs a platform implementation.
  ImagePickerAurora() {
    cameraDelegate = AuroraImagePickerDelegate();
  }

  static const imageTypeGroup = XTypeGroup(label: 'Images', mimeTypes: <String>['image/*']);
  static const videoTypeGroup = XTypeGroup(label: 'Videos', mimeTypes: <String>['video/*']);
  static const mediaTypeGroup = XTypeGroup(label: 'Images and Videos', mimeTypes: <String>['image/*', 'video/*']);

  /// Registers this class as the default instance of [ImagePickerPlatform].
  static void registerWith() {
    ImagePickerPlatform.instance = ImagePickerAurora();
  }

  // This is soft-deprecated in the platform interface, and is only implemented
  // for compatibility. Callers should be using getImageFromSource.
  @override
  Future<PickedFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    final file = await getImageFromSource(
      source: source,
      options: ImagePickerOptions(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
      ),
    );
    if (file != null) {
      return PickedFile(file.path);
    }
    return null;
  }

  // This is soft-deprecated in the platform interface, and is only implemented
  // for compatibility. Callers should be using getVideo.
  @override
  Future<PickedFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    final file = await getVideo(
      source: source,
      preferredCameraDevice: preferredCameraDevice,
      maxDuration: maxDuration,
    );
    if (file != null) {
      return PickedFile(file.path);
    }
    return null;
  }

  // This is soft-deprecated in the platform interface, and is only implemented
  // for compatibility. Callers should be using getImageFromSource.
  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    return getImageFromSource(
      source: source,
      options: ImagePickerOptions(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
      ),
    );
  }

  // [ImagePickerOptions] options are not currently supported. If any
  // of its fields are set, they will be silently ignored.
  //
  // If source is `ImageSource.camera`, a `StateError` will be thrown
  // unless a [cameraDelegate] is set.
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    switch (source) {
      case ImageSource.camera:
        return super.getImageFromSource(source: source, options: options);
      case ImageSource.gallery:
        final file = await openFile(acceptedTypeGroups: <XTypeGroup>[imageTypeGroup]);
        return file;
    }
    // Ensure that there's a fallback in case a new source is added.
    // ignore: dead_code
    throw UnimplementedError('Unknown ImageSource: $source');
  }

  // `preferredCameraDevice` and `maxDuration` arguments are not currently
  // supported. If either of these arguments are supplied, they will be silently
  // ignored.
  //
  // If source is `ImageSource.camera`, a `StateError` will be thrown
  // unless a [cameraDelegate] is set.
  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    switch (source) {
      case ImageSource.camera:
        return super.getVideo(source: source, preferredCameraDevice: preferredCameraDevice, maxDuration: maxDuration);
      case ImageSource.gallery:
        final file = await openFile(acceptedTypeGroups: <XTypeGroup>[videoTypeGroup]);
        return file;
    }
    // Ensure that there's a fallback in case a new source is added.
    // ignore: dead_code
    throw UnimplementedError('Unknown ImageSource: $source');
  }

  // `maxWidth`, `maxHeight`, and `imageQuality` arguments are not currently
  // supported. If any of these arguments are supplied, they will be silently
  // ignored.
  @override
  Future<List<XFile>> getMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[imageTypeGroup]);
    return files;
  }

  // `maxWidth`, `maxHeight`, and `imageQuality` arguments are not currently
  // supported. If any of these arguments are supplied, they will be silently
  // ignored.
  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    List<XFile> files;
    if (options.allowMultiple) {
      files = await openFiles(acceptedTypeGroups: <XTypeGroup>[mediaTypeGroup]);
    } else {
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[mediaTypeGroup]);
      files = <XFile>[if (file != null) file];
    }
    return files;
  }

  @override
  Future<LostDataResponse> getLostData() {
    throw UnsupportedError('Method getLostData() is Android only.');
  }

  @override
  Future<LostData> retrieveLostData() {
    throw UnsupportedError('Method retrieveLostData() is Android only.');
  }

  @override
  /// `MultiImagePickerOptions.limit` and `ImageOptions.requestFullMetadata` are not yet supported on AuroraOS.
  ///
  /// If any of these arguments are supplied, they will be silently ignored.
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) => getMultiImage(
          imageQuality: options.imageOptions.imageQuality,
          maxHeight: options.imageOptions.maxHeight,
          maxWidth: options.imageOptions.maxWidth,
        );

  @override
  /// `options parameter` is not yet supported in AuroraOS implementation of plugin.
  ///
  /// If provided, it will be silently ignored.
  Future<List<XFile>> getMultiVideoWithOptions({
    MultiVideoPickerOptions options = const MultiVideoPickerOptions(),
  }) => openFiles(acceptedTypeGroups: <XTypeGroup>[videoTypeGroup]);

  @override
  Future<List<PickedFile>?> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) => getMultiImage(
          imageQuality: imageQuality,
          maxHeight: maxWidth,
          maxWidth: maxWidth,
        ).then((files) => files.map<PickedFile>((e) => PickedFile(e.path)).toList());

  @override
  bool supportsImageSource(ImageSource source) => true;
}
