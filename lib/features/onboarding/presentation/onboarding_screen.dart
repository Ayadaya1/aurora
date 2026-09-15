import 'package:aurora/core/theme/app_colors.dart';
import 'package:aurora/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:aurora/features/onboarding/presentation/widgets/page_indicator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    OnboardingPageData(
      icon: Icons.camera_alt_outlined,
      title: 'Сфотографируй формулу',
      description: 'Сделай фото формулы или выбери изображение из галереи.',
    ),
    OnboardingPageData(
      icon: Icons.draw_outlined,
      title: 'Или нарисуй её',
      description: 'Если формула у тебя в голове — просто нарисуй её пальцем.',
    ),
    OnboardingPageData(
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

  Future<void> _next() async {
    if (_currentPage == _pages.length - 1) return _finish();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    style: TextStyle(color: AppColors.ink.withOpacity(0.55)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => OnboardingPageView(data: _pages[i]),
                ),
              ),
              PageIndicator(count: _pages.length, current: _currentPage),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
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
