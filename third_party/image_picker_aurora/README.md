# image_picker_aurora

The Aurora implementation of [`image_picker`](https://pub.dev/packages/image_picker).

## Usage

You have to include `image_picker` as dependencies in your `pubspec.yaml` file.

> Supports only OS Aurora 5+!

**pubspec.yaml**

```yaml
dependencies:
  image_picker: ^1.1.0
```

By default, ImageSource.camera is not supported, since unlike on Android and iOS there is no system-provided UI for taking photos. However, the Aurora implementations allow delegating to a camera handler by setting a cameraDelegate before using image_picker.

This package has a default implementation of AuroraCameraDelegate, which can be called using setUpDefaultAuroraCameraDelegate():

```dart
import 'package:image_picker_aurora/image_picker_aurora.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Set up default implementation with navigatorKey
  setUpDefaultAuroraCameraDelegate(navigatorKey);
  runApp(const MyApp());
}
...
Widget build(BuildContext context) {
    // Put navigatorKey to MaterialApp
    return MaterialApp(
      navigatorKey: navigatorKey,
    );
}
...
final ImagePickerPlatform _picker = ImagePickerPlatform.instance;

final imageFileFromGallery = _picker.getImageFromSource(source: ImageSource.gallery);

final imageFileFromCamera = _picker.getImageFromSource(source: ImageSource.camera);

final videoFromGallery = _picker.getVideo(source: ImageSource.gallery);
```

The default implementation uses camera_aurora, which does not support video recording yet. Trying to get a video from ImageSource.camera will throw error.

## Сustom implementation

If the default implementation of the AuroraCameraDelegate does not meet your development needs, you can create a custom implementation using the same approach as for desktop platforms. You can find information about this on the Image Picker package page: https://pub.dev/packages/image_picker#windows-macos-and-linux.
