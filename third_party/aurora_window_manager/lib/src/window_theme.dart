import 'package:flutter/material.dart';

class WindowTheme {
  factory WindowTheme.empty() {
    return WindowTheme(
      isDark: true,
      statusbarHeight: 0,
      statusbarBaseline: 0,
      highlightColor: Colors.black,
      primaryColor: Colors.black,
      secondaryColor: Colors.black,
      secondaryHighlightColor: Colors.black,
    );
  }

  WindowTheme({
    required this.isDark,
    required this.statusbarHeight,
    required this.statusbarBaseline,
    required this.highlightColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.secondaryHighlightColor,
  });

  final bool isDark;
  final double statusbarHeight;
  final double statusbarBaseline;
  final Color highlightColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color secondaryHighlightColor;

  @override
  String toString() {
    return '''WindowTheme{\n
\tisDark: $isDark,\n
\tstatusbarHeight: $statusbarHeight,\n
\tstatusbarBaseline: $statusbarBaseline,\n
\thighlightColor: $highlightColor,\n
\tprimaryColor: $primaryColor,\n
\tsecondaryColor: $secondaryColor,\n
\tsecondaryHighlightColor: $secondaryHighlightColor\n}\n
''';
  }
}
