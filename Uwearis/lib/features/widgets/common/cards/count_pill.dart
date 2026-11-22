import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Item-count badge. Deliberately not [AppColors.accent], which signals
/// "tappable" elsewhere.
class CountPill extends StatelessWidget {
  final int count;

  const CountPill({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.pillRadius),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Transform.translate(
        offset: Offset(
          0,
          -AppTextStyle.capCentreDrop(AppTextStyle.medium14.fontSize!),
        ),
        child: Text(
          '$count',
          textScaler: TextScaler.noScaling,
          style: AppTextStyle.medium14,
        ),
      ),
    );
  }
}
