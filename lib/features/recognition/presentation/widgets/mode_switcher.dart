import 'package:flutter/material.dart';

import 'package:aurora/core/theme/app_colors.dart';
import 'package:aurora/features/recognition/presentation/controllers/recognition_controller.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final RecognitionMode mode;
  final ValueChanged<RecognitionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              selected: mode == RecognitionMode.photo,
              icon: Icons.photo_camera_outlined,
              label: 'Фото',
              onTap: () => onChanged(RecognitionMode.photo),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeButton(
              selected: mode == RecognitionMode.drawing,
              icon: Icons.edit_outlined,
              label: 'Рисование',
              onTap: () => onChanged(RecognitionMode.drawing),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 40,
      decoration: BoxDecoration(
        color: selected ? AppColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.ink.withOpacity(0.55),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}