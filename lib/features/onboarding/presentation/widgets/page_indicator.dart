import 'package:flutter/material.dart';

import 'package:aurora/core/theme/app_colors.dart';

class PageIndicator extends StatelessWidget {
  const PageIndicator({super.key, required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teal
                : AppColors.teal.withOpacity(0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}