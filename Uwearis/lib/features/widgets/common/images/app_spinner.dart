import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Loading indicator for brief reads. Long AI waits use `LoadingOverlay`
/// instead, which makes short waits feel slower.
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
