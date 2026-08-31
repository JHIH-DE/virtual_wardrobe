import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// The app's standard status confirmation — an icon + [message] in a
/// centered card, shown over whatever page is current and auto-dismissing
/// itself after [duration]. Meant to be shown on the page the user lands on
/// after a save flow pops back to it, not on the page being popped (whose
/// context is gone by the time it would matter).
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
      // Without a Material ancestor, Text falls back to
      // DefaultTextStyle.fallback()'s debug style — a bright yellow
      // underline meant to flag exactly this kind of missing ancestor.
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
