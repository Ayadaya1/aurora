import 'dart:io';

import 'package:flutter/material.dart';

import 'package:aurora/core/theme/app_colors.dart';

class PhotoInputView extends StatelessWidget {
  const PhotoInputView({
    super.key,
    required this.imagePath,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onRemove,
  });

  final String? imagePath;
  final Future<void> Function() onPickGallery;
  final Future<void> Function() onTakePhoto;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) return _buildSelected(imagePath!);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _Action(
              icon: Icons.photo_library_outlined,
              title: 'Галерея',
              subtitle: 'Выбрать фото',
              onTap: onPickGallery,
            ),
          ),
          Container(width: 1, height: 100, color: Colors.grey.shade200),
          Expanded(
            child: _Action(
              icon: Icons.camera_alt_outlined,
              title: 'Камера',
              subtitle: 'Сделать фото',
              onTap: onTakePhoto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelected(String path) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(path), fit: BoxFit.contain),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black.withOpacity(0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
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
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.teal.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.teal, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.ink.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
