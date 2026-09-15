import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:aurora/core/theme/app_colors.dart';

class LatexResultView extends StatelessWidget {
  const LatexResultView({
    super.key,
    required this.controller,
    required this.latex,
  });

  final WebViewController controller;
  final String? latex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: latex == null ? null : () => _copy(context),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
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
          children: [
            WebViewWidget(controller: controller),
            if (latex != null)
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
                        color: AppColors.ink.withOpacity(0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(Icons.copy_outlined,
                      size: 18, color: AppColors.ink.withOpacity(0.55)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: latex!));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('LaTeX скопирован'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}