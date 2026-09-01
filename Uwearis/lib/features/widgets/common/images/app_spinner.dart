import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Lightweight, generic loading indicator for brief network reads (list
/// fetches, page loads under a few seconds). Distinct from the branded
/// "blooming flower" animation reserved for [LoadingOverlay]'s
/// long-running AI/generation waits — using that everywhere made short
/// reads feel slower than they actually are.
class AppSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const AppSpinner({
    super.key,
    this.size = 36,
    this.strokeWidth = 5,
    this.color = AppColors.borderStrong,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
  }
}
