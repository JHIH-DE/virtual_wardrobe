import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Small pill-shaped badge for a plain item count (e.g. next to "Closet"/
/// "Outfits" in an AppToolBar title). Deliberately not [AppColors.accent]
/// (purple) — that color means "tappable" elsewhere in the app, and this
/// badge isn't.
class CountPill extends StatelessWidget {
  final int count;

  const CountPill({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        '$count',
        textScaler: TextScaler.noScaling,
        style: AppTextStyle.medium13,
      ),
    );
  }
}
