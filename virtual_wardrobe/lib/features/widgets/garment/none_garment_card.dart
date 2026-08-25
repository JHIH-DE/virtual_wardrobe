import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

/// Selectable "none" tile matching [GarmentCard]'s shape — for garment
/// pickers that let the user explicitly pick "nothing" for a slot instead
/// of a garment (e.g. clearing an optional accessory).
class NoneGarmentCard extends StatelessWidget {
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  const NoneGarmentCard({
    super.key,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.garmentCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pageBackground : AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: isSelected
                ? Border.all(color: AppColors.borderStrong, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 32, color: AppColors.icon),
                const SizedBox(height: 8),
                Text(label, style: AppTextStyle.bold14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
