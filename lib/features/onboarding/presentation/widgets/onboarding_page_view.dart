import 'package:flutter/material.dart';

import 'package:aurora/core/theme/app_colors.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
}

class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({super.key, required this.data});
  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(data.icon, size: 72, color: AppColors.teal),
        ),
        const SizedBox(height: 42),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          data.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.ink.withOpacity(0.60),
          ),
        ),
      ],
    );
  }
}