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
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.garmentCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upper — white background, image
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.white,
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
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 13,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(height: 1, color: AppColors.border),
                    // Lower — white background, text
                    Container(
                      height: AppDimens.garmentCardInfoHeight,
                      color: Colors.white,
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
                          if (garment.color != null &&
                              garment.color!.isNotEmpty)
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
                if (isSelected)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: 1.0,
                      child: const ColoredBox(color: AppColors.statusClicked),
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
