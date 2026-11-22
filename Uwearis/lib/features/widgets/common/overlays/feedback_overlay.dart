import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import 'dialog_glass_panel.dart';

/// Auto-dismissing status confirmation. Show it on the page a flow pops back
/// to, not the page being popped.
Future<void> showFeedbackOverlay(
  BuildContext context, {
  required String message,
  String imagePath = 'assets/images/success.png',
  Duration duration = const Duration(seconds: 2),
}) async {
  // Its own route, so only this overlay is closed below.
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) {
      return Center(
        // Without a Material ancestor, Text gets the yellow-underline debug style.
        child: Material(
          type: MaterialType.transparency,
          child: DialogGlassPanel(
            borderRadius: BorderRadius.circular(AppDimens.dialogRadius),
            child: Container(
              width: 260,
              constraints: const BoxConstraints(minHeight: 130),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(imagePath, width: 64, height: 64),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
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
    },
  );
  navigator.push(route);
  await Future.delayed(duration);
  // A system back may already have closed it, or something may sit on top
  // of it by now.
  if (!route.isActive) return;
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}
