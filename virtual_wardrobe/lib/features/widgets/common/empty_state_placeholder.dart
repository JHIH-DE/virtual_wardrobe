import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Centered "nothing here yet" message, optionally with a leading icon and/or
/// a background decoration (e.g. a bordered box for a compact inline slot).
class EmptyStatePlaceholder extends StatelessWidget {
  final String message;
  final IconData? icon;
  final double? height;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry padding;

  const EmptyStatePlaceholder({
    super.key,
    required this.message,
    this.icon,
    this.height,
    this.decoration,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: decoration != null ? double.infinity : null,
      padding: padding,
      decoration: decoration,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 64, color: AppColors.icon),
              const SizedBox(height: 16),
            ],
            Text(
              message,
              style: AppTextStyle.regular16.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
