import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.camera_alt_outlined,
      title: 'Сфотографируй формулу',
      description: 'Сделай фото формулы или выбери изображение из галереи.',
    ),
    _OnboardingPage(
      icon: Icons.draw_outlined,
      title: 'Или нарисуй её',
      description: 'Если формула у тебя в голове — просто нарисуй её пальцем.',
    ),
    _OnboardingPage(
      icon: Icons.functions,
      title: 'Получи LaTeX',
      description:
          'Нейросеть распознает формулу и превратит её в аккуратный LaTeX.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    context.go('/recognize');
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: _Brand.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Пропустить',
                    style: TextStyle(color: _Brand.ink.withOpacity(0.55)),
                  ),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (_, index) {
                    final item = _pages[index];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: _Brand.teal.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 72, color: _Brand.teal),
                        ),

                        const SizedBox(height: 42),

                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _Brand.ink,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: _Brand.ink.withOpacity(0.60),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final selected = index == _currentPage;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: selected ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected
                          ? _Brand.teal
                          : _Brand.teal.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Brand.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Начать' : 'Далее',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _Brand {
  static const Color ink = Color(0xFF263238);
  static const Color teal = Color(0xFF18AECF);
  static const Color background = Color(0xFFF3F6F8);
  static const Color cardBackground = Colors.white;
}

enum _InputMode { photo, drawing }

class _Stroke {
  final List<Offset?> points;
  final double strokeWidth;

  _Stroke({required this.points, required this.strokeWidth});
}

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;

  _DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final dotPaint = Paint()..color = _Brand.ink.withOpacity(0.06);

    const spacing = 22.0;

    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    for (final stroke in strokes) {
      final paint = Paint()
        ..color = _Brand.ink
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
  final ImagePicker _imagePicker = ImagePicker();
  final Dio _dio = Dio();

  final GlobalKey _drawingKey = GlobalKey();

  late WebViewController _webViewController;

  _InputMode _inputMode = _InputMode.photo;

  XFile? _selectedImage;

  double _currentStrokeWidth = 4.0;

  bool _isTouchingCanvas = false;
  bool _isRecognizing = false;

  String? _currentFormula;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(_buildLatexHtml(null));
  }

  void _setInputMode(_InputMode mode) {
    if (_inputMode == mode) {
      return;
    }

    setState(() {
      _inputMode = mode;
      _selectedImage = null;
      _strokes.clear();
      _currentFormula = null;
    });

    _webViewController.loadHtmlString(_buildLatexHtml(null));
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _selectedImage = image;
    });
  }

  Future<void> _takePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _selectedImage = image;
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _strokes.add(
        _Stroke(
          points: [details.localPosition],
          strokeWidth: _currentStrokeWidth,
        ),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_strokes.isEmpty) {
      return;
    }

    setState(() {
      _strokes.last.points.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_strokes.isEmpty) {
      return;
    }

    setState(() {
      _strokes.last.points.add(null);
    });
  }

  Future<Uint8List> _captureDrawing() async {
    final boundary =
        _drawingKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 2.0);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Не удалось создать PNG');
    }

    return byteData.buffer.asUint8List();
  }

  Future<void> _recognizeFormula() async {
    if (_inputMode == _InputMode.photo && _selectedImage == null) {
      _showError('Выберите изображение или сделайте фото');
      return;
    }

    if (_inputMode == _InputMode.drawing && _strokes.isEmpty) {
      _showError('Нарисуйте формулу на холсте');
      return;
    }

    setState(() {
      _isRecognizing = true;
    });

    try {
      final formData = FormData();

      formData.fields.add(
        MapEntry(
          'mode',
          _inputMode == _InputMode.photo ? 'photo' : 'drawing',
        ),
      );

      if (_inputMode == _InputMode.photo) {
        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(
              _selectedImage!.path,
              filename: 'formula.jpg',
            ),
          ),
        );
      } else {
        final png = await _captureDrawing();

        formData.files.add(
          MapEntry(
            'image',
            MultipartFile.fromBytes(png, filename: 'drawing.png'),
          ),
        );
      }

      final response = await _dio.post(
        'http://161.104.53.233:8000/recognize',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          responseType: ResponseType.json,
        ),
      );

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      final latex = data['latex']?.toString();

      if (latex == null || latex.isEmpty) {
        throw Exception('Сервер не вернул LaTeX');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentFormula = latex;
      });

      _webViewController.loadHtmlString(_buildLatexHtml(latex));
    } on DioException catch (e) {
      print('STATUS: ${e.response?.statusCode}');
      print('DATA: ${e.response?.data}');
      print('HEADERS: ${e.response?.headers}');
      if (!mounted) {
        return;
      }

      final message =
          e.response?.data?.toString() ??
          e.message ??
          'Ошибка соединения с сервером';

      _showError(message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildLatexHtml(String? formula) {
    final inkHex = '#${_Brand.ink.value.toRadixString(16).substring(2)}';

    final bodyScript = formula == null
        ? '''
document.getElementById('formula').innerHTML =
  '<span style="font-size:18px;color:#90A4AE;">Здесь появится распознанная формула</span>';
'''
        : '''
katex.render(
  ${_jsString(formula)},
  document.getElementById('formula'),
  {
    throwOnError: false,
    displayMode: true
  }
);
''';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport"
        content="width=device-width, initial-scale=1.0">

  <link
    rel="stylesheet"
    href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
  >

  <script
    defer
    src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js">
  </script>

  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(
        135deg,
        #ffffff 0%,
        #f0fafc 100%
      );
      font-size: 30px;
      color: $inkHex;
    }

    #formula {
      padding: 20px 28px;
      border-radius: 14px;
      background: #ffffff;
      box-shadow:
        0 4px 18px rgba(38, 50, 56, 0.08);
      border:
        1px solid rgba(24, 174, 207, 0.25);
      text-align: center;
    }

    .katex {
      color: $inkHex;
    }
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

  String _jsString(String value) {
    final escaped = value
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');

    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: _isTouchingCanvas
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeSwitcher(),
              const SizedBox(height: 12),
              _inputMode == _InputMode.photo
                  ? _buildPhotoInput()
                  : _buildDrawingInput(),
              const SizedBox(height: 16),
              _buildRecognizeButton(),
              const SizedBox(height: 16),
              _sectionLabel(Icons.functions, 'Результат'),
              const SizedBox(height: 8),
              _buildLatexCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Expanded(
            child: _modeButton(
              mode: _InputMode.photo,
              icon: Icons.photo_camera_outlined,
              label: 'Фото',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _modeButton(
              mode: _InputMode.drawing,
              icon: Icons.edit_outlined,
              label: 'Рисование',
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required _InputMode mode,
    required IconData icon,
    required String label,
  }) {
    final selected = _inputMode == mode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 40,
      decoration: BoxDecoration(
        color: selected ? _Brand.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _inputMode = mode;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : _Brand.ink.withOpacity(0.55),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _Brand.ink.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoInput() {
    if (_selectedImage != null) {
      return _buildSelectedImage();
    }

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Brand.teal.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: _Brand.ink.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _imageAction(
              icon: Icons.photo_library_outlined,
              title: 'Галерея',
              subtitle: 'Выбрать фото',
              onTap: _pickFromGallery,
            ),
          ),
          Container(width: 1, height: 100, color: Colors.grey.shade200),
          Expanded(
            child: _imageAction(
              icon: Icons.camera_alt_outlined,
              title: 'Камера',
              subtitle: 'Сделать фото',
              onTap: _takePhoto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          Icon(
            Icons.line_weight,
            size: 19,
            color: _Brand.ink.withOpacity(0.55),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                activeTrackColor: _Brand.teal,
                inactiveTrackColor: _Brand.teal.withOpacity(0.18),
                thumbColor: _Brand.teal,
                overlayColor: _Brand.teal.withOpacity(0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: _currentStrokeWidth,
                min: 1,
                max: 14,
                onChanged: (value) {
                  setState(() {
                    _currentStrokeWidth = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _Brand.teal.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _Brand.teal, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _Brand.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: _Brand.ink.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImage() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_selectedImage!.path), fit: BoxFit.contain),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black.withOpacity(0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _removeImage,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingInput() {
    return Column(
      children: [
        RepaintBoundary(
          key: _drawingKey,
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white,
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
              onPointerDown: (_) {
                setState(() {
                  _isTouchingCanvas = true;
                });
              },
              onPointerUp: (_) {
                setState(() {
                  _isTouchingCanvas = false;
                });
              },
              onPointerCancel: (_) {
                setState(() {
                  _isTouchingCanvas = false;
                });
              },
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
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _clearCanvas,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Очистить'),
              style: TextButton.styleFrom(
                foregroundColor: _Brand.ink.withOpacity(0.65),
              ),
            ),
            const Spacer(),
            Icon(Icons.line_weight, size: 18, color: Colors.grey.shade500),
            SizedBox(
              width: 130,
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
                    setState(() {
                      _currentStrokeWidth = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

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

  Widget _buildLatexCard() {
    return GestureDetector(
      onTap: _currentFormula == null
          ? null
          : () async {
        await Clipboard.setData(
          ClipboardData(text: _currentFormula!),
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LaTeX скопирован'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
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
        child: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_currentFormula != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _Brand.ink.withOpacity(0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.copy_outlined,
                    size: 18,
                    color: _Brand.ink.withOpacity(0.55),
                  ),
                ),
              ),
          ],
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
}
