import 'package:aurora_window_manager/aurora_window_manager.dart';
import 'package:flutter/material.dart';

typedef WindowModeBuilder = Widget Function(BuildContext context, WindowMode windowMode);

class AuroraWindowModeChanger extends StatefulWidget {
  const AuroraWindowModeChanger({super.key, required this.windowModeBuilder});

  /// Called at layout time to construct the widget tree depending on current window mode.
  /// Possible window modes are: foreground and cover.
  /// Cover mode is used when application works in the background.
  final WindowModeBuilder windowModeBuilder;

  @override
  State<AuroraWindowModeChanger> createState() => _AuroraWindowModeChangerState();
}

class _AuroraWindowModeChangerState extends State<AuroraWindowModeChanger> {
  @override
  void initState() {
    super.initState();
    AuroraWindowManager.addWindowModeListener(_onWindowModeChanged);
  }

  @override
  Widget build(BuildContext context) => widget.windowModeBuilder(context, AuroraWindowManager.getWindowMode());

  void _onWindowModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AuroraWindowManager.removeWindowModeListener(_onWindowModeChanged);
    super.dispose();
  }
}
