Based on flutter_math_fork 0.7.4 from https://pub.dev/packages/flutter_math_fork/versions/0.7.4 (upstream: https://github.com/simpleclub/flutter_math).

Four platform switches in selectable.dart, line_editable.dart and gesture_detector_builder_selectable.dart add a default Material/Linux branch. Flutter Aurora extends TargetPlatform with aurora, which makes the upstream exhaustive switches fail to compile, even when only Math is used. The fallback also builds on upstream Flutter without referencing its absent TargetPlatform.aurora enum. No math parsing, layout or fonts were changed.

Retain the upstream licenses when updating this copy.
