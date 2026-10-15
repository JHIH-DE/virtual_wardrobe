import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Auto-dismissing status confirmation. Show it on the page a flow pops back
/// to, not the page being popped.
Future<void> showFeedbackOverlay(
  BuildContext context, {
  required String message,
  String imagePath = 'assets/images/success.png',
  Duration duration = const Duration(seconds: 2),
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      // Without a Material ancestor, Text gets the yellow-underline debug style.
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 260,
          height: 130,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(imagePath, width: 64, height: 64),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTextStyle.bold20.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await Future.delayed(duration);
  if (context.mounted) Navigator.of(context).pop();
}
