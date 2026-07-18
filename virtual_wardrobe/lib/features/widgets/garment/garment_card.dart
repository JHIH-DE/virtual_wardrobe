import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import 'garment_image.dart';

class GarmentCard extends StatelessWidget {
  final Garment garment;
  final bool isSelected;
  final bool showSelectionIndicator;
  final VoidCallback? onTap;

  const GarmentCard({
    super.key,
    required this.garment,
    this.isSelected = false,
    this.showSelectionIndicator = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isSelected ? AppColors.pageBackground : AppColors.surface;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.garmentCardHeight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Painted after the child (unlike `decoration`), so this stays
          // visible over the card's opaque image/text fills instead of
          // being covered by them.
          foregroundDecoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderStrong, width: 1.5),
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upper — image
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        color: cardColor,
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: GarmentImage(
                            url: garment.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            borderRadius: 0,
                          ),
                        ),
                      ),
                      if (showSelectionIndicator)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadowResting,
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.textOnPrimary,
                                    size: 14,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                // Divider
                Container(height: 1, color: AppColors.borderSubtle),
                // Lower — text
                Container(
                  height: AppDimens.garmentCardInfoHeight,
                  color: cardColor,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        garment.name,
                        style: AppTextStyle.bold14,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (garment.color != null && garment.color!.isNotEmpty)
                        Text(
                          garment.color!,
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
