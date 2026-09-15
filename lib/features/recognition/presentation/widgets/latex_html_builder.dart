import 'package:aurora/core/theme/app_colors.dart';

abstract final class LatexHtmlBuilder {
  static String build(String? formula) {
    final inkHex = '#${AppColors.ink.value.toRadixString(16).substring(2)}';

    final bodyScript = formula == null
        ? '''
document.getElementById('formula').innerHTML =
  '<span style="font-size:18px;color:#90A4AE;">Здесь появится распознанная формула</span>';
'''
        : '''
katex.render(
  ${_jsString(formula)},
  document.getElementById('formula'),
  { throwOnError: false, displayMode: true }
);
''';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
  <script defer
          src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
  <style>
    html, body {
      margin: 0; padding: 0; height: 100%;
      display: flex; align-items: center; justify-content: center;
      background: linear-gradient(135deg, #ffffff 0%, #f0fafc 100%);
      font-size: 30px; color: $inkHex;
    }
    #formula {
      padding: 20px 28px; border-radius: 14px; background: #ffffff;
      box-shadow: 0 4px 18px rgba(38, 50, 56, 0.08);
      border: 1px solid rgba(24, 174, 207, 0.25);
      text-align: center;
    }
    .katex { color: $inkHex; }
  </style>
</head>
<body>
  <div id="formula"></div>
  <script>
    window.onload = function() { $bodyScript };
  </script>
</body>
</html>
''';
  }

  static String _jsString(String value) {
    final escaped = value
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return '"$escaped"';
  }
}