// draw_and_latex_screen.dart
//
// A Flutter screen combining:
//  1. A freehand drawing canvas built with CustomPainter.
//  2. A big "Распознать" (Recognize) button — currently just swaps in a
//     random LaTeX formula, but is the hook point for real AI-based
//     handwritten-formula recognition later on.
//  3. A WebView rendering the resulting LaTeX formula via KaTeX.
//
// Styled around a brand palette pulled from the company logo (a dark
// navy + teal checkmark):
//   - Ink   (dark navy)  #263238
//   - Teal  (accent)     #18AECF
//
// Dependencies (add to pubspec.yaml):
//   dependencies:
//     webview_flutter: ^4.7.0
//
// Assets (add to pubspec.yaml, and drop logo.png in assets/images/ if used
// elsewhere in the app):
//   flutter:
//     assets:
//       - assets/images/logo.png
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => const DrawAndLatexScreen(),
//   ));

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ---------------------------------------------------------------------------
// Brand palette
// ---------------------------------------------------------------------------
class _Brand {
  static const Color ink = Color(0xFF263238); // dark navy from the logo
  static const Color teal = Color(0xFF18AECF); // teal from the logo
  static const Color tealLight = Color(0xFF5FD3E8);
  static const Color background = Color(0xFFF3F6F8);
  static const Color cardBackground = Colors.white;
}

/// A single freehand stroke, made up of a list of points.
/// A null point acts as a "pen up" marker, separating strokes.
class _Stroke {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  _Stroke({required this.points, required this.color, required this.strokeWidth});
}

/// CustomPainter that draws all recorded strokes onto the canvas.
class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;

  _DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    // Faint dot-grid background so the canvas doesn't feel like a blank void.
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final dotPaint = Paint()..color = _Brand.ink.withOpacity(0.06);
    const spacing = 22.0;
    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    // We mutate the same underlying `_strokes` list in place while drawing
    // (for performance), so comparing list references here would always be
    // false. Repainting a handful of strokes each frame is cheap, so just
    // always repaint; this guarantees new points show up as you draw.
    return true;
  }
}

class DrawAndLatexScreen extends StatefulWidget {
  const DrawAndLatexScreen({super.key});

  @override
  State<DrawAndLatexScreen> createState() => _DrawAndLatexScreenState();
}

class _DrawAndLatexScreenState extends State<DrawAndLatexScreen> {
  final List<_Stroke> _strokes = [];
  Color _currentColor = _Brand.ink;
  double _currentStrokeWidth = 4.0;

  // True while a finger/pointer is down on the canvas. Used to disable the
  // outer SingleChildScrollView so it never steals vertical drag gestures
  // away from the drawing surface.
  bool _isTouchingCanvas = false;

  // True while a "recognition" is in progress, so the button can show a
  // brief loading state — this is where a real API call will eventually go.
  bool _isRecognizing = false;

  late WebViewController _webViewController;
  final Random _random = Random();

  // A small pool of sample LaTeX formulas to pick from at random.
  // TODO: replace this with the actual recognized formula once an AI
  // recognition backend is wired up (e.g. send the canvas strokes/image to
  // a model and use its LaTeX output here instead of a random pick).
  static const List<String> _sampleFormulas = [
    r'E = mc^2',
    r'\int_{a}^{b} f(x)\,dx = F(b) - F(a)',
    r'e^{i\pi} + 1 = 0',
    r'\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
    r'\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}',
    r'\nabla \cdot \mathbf{E} = \frac{\rho}{\varepsilon_0}',
    r'a^2 + b^2 = c^2',
    r'\lim_{x \to 0} \frac{\sin x}{x} = 1',
  ];

  String? _currentFormula;

  // Swatches offered in the toolbar — brand colors first, then a few extras.
  static const List<Color> _swatches = [
    _Brand.ink,
    _Brand.teal,
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.deepPurpleAccent,
  ];

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(_buildLatexHtml(null));
  }

  String _pickRandomFormula() {
    return _sampleFormulas[_random.nextInt(_sampleFormulas.length)];
  }

  /// Builds a minimal, branded HTML page that loads KaTeX from a CDN and
  /// renders the given LaTeX string. When [formula] is null, shows a
  /// friendly placeholder instead (nothing recognized yet).
  String _buildLatexHtml(String? formula) {
    final inkHex = '#${_Brand.ink.value.toRadixString(16).substring(2)}';

    final bodyScript = formula == null
        ? '''
    document.getElementById('formula').innerHTML =
      '<span style="font-size:18px;color:#90A4AE;">Нажмите «Распознать», чтобы получить формулу</span>';
'''
        : '''
    katex.render("${formula.replaceAll(r'\', r'\\')}", document.getElementById('formula'), {
      throwOnError: false,
      displayMode: true
    });
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
      margin: 0;
      padding: 0;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #ffffff 0%, #f0fafc 100%);
      font-size: 30px;
      color: $inkHex;
    }
    #formula {
      padding: 20px 28px;
      border-radius: 14px;
      background: #ffffff;
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
    window.onload = function() {
$bodyScript
    };
  </script>
</body>
</html>
''';
  }

  /// Placeholder "recognition" step. For now it just waits briefly and
  /// picks a random sample formula. Swap the body of this method for a real
  /// call to an AI recognition service (send `_strokes` — or a rendered
  /// image of them — and use the returned LaTeX string).
  Future<void> _recognizeFormula() async {
    setState(() => _isRecognizing = true);

    await Future.delayed(const Duration(milliseconds: 600));
    final formula = _pickRandomFormula();

    setState(() {
      _currentFormula = formula;
      _isRecognizing = false;
    });
    _webViewController.loadHtmlString(_buildLatexHtml(formula));
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _strokes.add(_Stroke(
        points: [details.localPosition],
        color: _currentColor,
        strokeWidth: _currentStrokeWidth,
      ));
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _strokes.last.points.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _strokes.last.points.add(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.background,
      body: SafeArea(
        child: SingleChildScrollView(
          // Disabled entirely while a finger is on the canvas, so the
          // scroll view never enters the gesture arena and steals drags
          // away from the drawing surface.
          physics: _isTouchingCanvas
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(Icons.edit_outlined, 'Рисунок'),
              const SizedBox(height: 10),
              _buildDrawingCard(),
              const SizedBox(height: 10),
              _buildClearButton(),
              const SizedBox(height: 14),
              _buildToolbar(),
              const SizedBox(height: 22),
              _buildRecognizeButton(),
              const SizedBox(height: 26),
              _sectionLabel(Icons.functions, 'Формула'),
              const SizedBox(height: 10),
              _buildLatexCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _Brand.teal),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _Brand.ink,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Drawing card
  // ---------------------------------------------------------------------
  Widget _buildDrawingCard() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: _Brand.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _Brand.ink.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Listener(
        // onPointerDown/Up fire immediately, before the gesture arena
        // decides who "wins" the drag — so this reliably locks the outer
        // scroll view the instant a finger touches the canvas.
        onPointerDown: (_) => setState(() => _isTouchingCanvas = true),
        onPointerUp: (_) => setState(() => _isTouchingCanvas = false),
        onPointerCancel: (_) => setState(() => _isTouchingCanvas = false),
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            size: Size.infinite,
            painter: _DrawingPainter(strokes: _strokes),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Delete/clear button, directly under the sketch panel
  // ---------------------------------------------------------------------
  Widget _buildClearButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _clearCanvas,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('Очистить холст'),
        style: TextButton.styleFrom(
          foregroundColor: _Brand.ink.withOpacity(0.65),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Toolbar: color swatches + stroke width, in a floating pill card
  // ---------------------------------------------------------------------
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _Brand.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _Brand.ink.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final color in _swatches) _colorSwatch(color),
          const SizedBox(width: 10),
          Container(width: 1, height: 28, color: Colors.grey.shade200),
          const SizedBox(width: 14),
          Icon(Icons.line_weight, size: 18, color: Colors.grey.shade500),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _Brand.teal,
                inactiveTrackColor: _Brand.teal.withOpacity(0.15),
                thumbColor: _Brand.teal,
                overlayColor: _Brand.teal.withOpacity(0.15),
                trackHeight: 3,
              ),
              child: Slider(
                value: _currentStrokeWidth,
                min: 1,
                max: 14,
                onChanged: (value) {
                  setState(() => _currentStrokeWidth = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    final bool selected = _currentColor == color;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _currentColor = color),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: selected ? 32 : 26,
          height: selected ? 32 : 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? _Brand.teal : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : [],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Big "Распознать" (Recognize) button
  // ---------------------------------------------------------------------
  Widget _buildRecognizeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRecognizing ? null : _recognizeFormula,
        style: ElevatedButton.styleFrom(
          backgroundColor: _Brand.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _Brand.teal.withOpacity(0.6),
          elevation: 4,
          shadowColor: _Brand.teal.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isRecognizing
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: 10),
            Text(
              'Распознать',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // LaTeX WebView card
  // ---------------------------------------------------------------------
  Widget _buildLatexCard() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: _Brand.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _Brand.ink.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: WebViewWidget(controller: _webViewController),
    );
  }
}
