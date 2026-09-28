// SPDX-FileCopyrightText: Copyright 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-FileCopyrightText: Copyright 2013 The Flutter Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

import 'src/image_picker_aurora.dart';

export 'src/image_picker_aurora.dart';

@pragma('vm:entry-point')
void imagePickerAuroraOpenCameraDialog() {
  openCameraDialogImpl();
}
