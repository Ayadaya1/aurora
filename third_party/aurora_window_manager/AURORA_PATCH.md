# Aurora Flutter 3.41.4 compatibility

Vendored from the official Aurora pub repository, aurora_window_manager 1.8.0:
https://sdk-repo.omprussia.ru/sdk/flutter/pub/artifacts/aurora_window_manager_1.8.0-pre.1776338301745.tar.gz
Source files retain Open Mobile Platform's BSD-3-Clause SPDX notices.
The published archive contains no standalone license file.

Keep the 1.8 implementation using the built-in `flutter/aurora-window-manager`
channel. Version 1.10's native plugin calls CreatePopupWindow, which is absent
from the embedder distributed with the tested Flutter 3.41.4 SDK. Both gallery
and camera fail before displaying a dialog with version 1.10.

The local patch also supplies readable fallback colors for empty/invalid theme
strings. Valid theme colors retain upstream behavior. Only Aurora builds apply
this override (tools/build-aurora.sh). Runtime verification of this replacement
requires rebuilding RPM 1.0.0+4; 1.0.0+3 still has the incompatible plugin.
