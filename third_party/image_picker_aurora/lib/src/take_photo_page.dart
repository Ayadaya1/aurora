// SPDX-FileCopyrightText: Copyright 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-FileCopyrightText: Copyright 2013 The Flutter Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:aurora_window_manager/aurora_window_manager.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TakePhotoPageData {
  const TakePhotoPageData({this.isPreferFront = false});

  final bool isPreferFront;

  Map<String, Object> toMap() {
    return {'isPreferFront': isPreferFront};
  }

  static TakePhotoPageData fromMap(Map<String, Object> params) {
    final isPreferFrontValue = params['isPreferFront'];
    return TakePhotoPageData(
      isPreferFront: isPreferFrontValue is bool ? isPreferFrontValue : false,
    );
  }
}

class TakePhotoPage extends StatefulWidget {
  const TakePhotoPage({super.key, required this.data});
  final TakePhotoPageData data;

  @override
  State<TakePhotoPage> createState() => _TakePhotoPageState();
}

class _TakePhotoPageState extends State<TakePhotoPage> {
  bool changingCamera = false;
  String? _cameraError;
  CameraController? _cameraController;

  Future<void> _initCameraController({bool isPreferFront = false}) async {
    final cameras = await availableCameras();
    if (!mounted) return;
    final backCameras = cameras.where(
      (element) => element.lensDirection == CameraLensDirection.back,
    );
    final frontCameras = cameras.where(
      (element) => element.lensDirection == CameraLensDirection.front,
    );
    final camera = isPreferFront
        ? frontCameras.firstOrNull ?? backCameras.firstOrNull
        : backCameras.firstOrNull ?? frontCameras.firstOrNull;

    if (camera == null) {
      throw CameraException(
        'cameraNotFound',
        'No one back or front cameras found',
      );
    }

    if (_cameraController != null) {
      if (_cameraController!.description.name == camera.name) return;

      // Change camera
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.setDescription(camera);
    } else {
      _cameraController = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  void initState() {
    super.initState();
    _loadCamera(isPreferFront: widget.data.isPreferFront);
  }

  Future<void> _loadCamera({required bool isPreferFront}) async {
    try {
      await _initCameraController(isPreferFront: isPreferFront);
      if (mounted) setState(() => _cameraError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _cameraError = 'Камера недоступна. Выберите фото из галереи.',
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFrontCamera =
        _cameraController?.description.lensDirection ==
        CameraLensDirection.front;
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _cameraError != null ||
              _cameraController == null ||
              !_cameraController!.value.isInitialized
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cameraError == null)
                    const CircularProgressIndicator()
                  else
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _cameraError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  TextButton(
                    onPressed: () => AuroraWindowManager.closeWindow({}),
                    child: const Text(
                      'Закрыть',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Center(
                  child: AnimatedOpacity(
                    opacity: !changingCamera ? 1 : 0,
                    duration: changingCamera
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    child: Transform.flip(
                      flipX: isFrontCamera,
                      // TODO implemets zoom, focus and other then camera_aurora implement it
                      child: _cameraController!.buildPreview(),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const SizedBox(height: 40, width: 40),
                          GestureDetector(
                            onTap: () async {
                              try {
                                final picture = await _cameraController!
                                    .takePicture();
                                if (mounted)
                                  AuroraWindowManager.closeWindow({
                                    'path': picture.path,
                                  });
                              } catch (_) {
                                if (mounted)
                                  setState(
                                    () => _cameraError =
                                        'Не удалось сделать фото. Попробуйте ещё раз.',
                                  );
                              }
                            },
                            child: SizedBox(
                              height: 70,
                              width: 70,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    width: 5,
                                    color: Colors.white,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 40,
                            width: 40,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0x33FFFFFF),
                                shape: BoxShape.circle,
                              ),
                              child: GestureDetector(
                                onTap: () async {
                                  if (!changingCamera) {
                                    changingCamera = true;
                                    setState(() {});
                                    await _loadCamera(
                                      isPreferFront: !isFrontCamera,
                                    );
                                    if (mounted)
                                      setState(() => changingCamera = false);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: SvgPicture.asset(
                                    'assets/sync.svg',
                                    package: 'image_picker_aurora',
                                    fit: BoxFit.scaleDown,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                      right: 10,
                    ),
                    child: IconButton(
                      onPressed: () => AuroraWindowManager.closeWindow({}),
                      icon: const SizedBox(
                        height: 30,
                        width: 30,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x33FFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
