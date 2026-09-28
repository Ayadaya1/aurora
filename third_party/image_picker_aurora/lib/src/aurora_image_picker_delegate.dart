// SPDX-FileCopyrightText: Copyright 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-FileCopyrightText: Copyright 2013 The Flutter Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:aurora_window_manager/aurora_window_manager.dart';
import 'package:camera/camera.dart';
import 'package:image_picker_aurora/src/camera_dialog.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'take_photo_page.dart';

class AuroraImagePickerDelegate extends ImagePickerCameraDelegate {

  @override
  Future<XFile?> takeVideo({
    ImagePickerCameraDelegateOptions options = const ImagePickerCameraDelegateOptions(),
  }) async {
    throw UnimplementedError('Video recording is not implemented in camera_aurora plugin');
  }

  @override
  Future<XFile?> takePhoto({
    ImagePickerCameraDelegateOptions options = const ImagePickerCameraDelegateOptions(),
  }) async {
    try {
      final isPreferFront = options.preferredCameraDevice == CameraDevice.front;
      final pathRes = await AuroraWindowManager.createWindow(
      entryPoint: 'imagePickerAuroraOpenCameraDialog',
      entryPointLibrary: 'package:image_picker_aurora/image_picker_aurora.dart',
      params: {
        'initialRoute': CameraDialogRoutes.camera.path,
        ...TakePhotoPageData(isPreferFront: isPreferFront)
            .toMap(),
      });
      final filePath = pathRes['path'];
      return filePath is String ? XFile(filePath) : null;
    } on CameraException {
      return null;
    }
  }
}
