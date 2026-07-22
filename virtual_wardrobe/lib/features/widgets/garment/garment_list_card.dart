import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../common/category_tag.dart';
import 'garment_image.dart';

class GarmentListCard extends StatelessWidget {
  final Garment garment;
  final VoidCallback? onTap;

  const GarmentListCard({super.key, required this.garment, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                child: SizedBox(
                  width: 80,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GarmentImage(
                      url: garment.imageUrl,
                      fit: BoxFit.fitHeight,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(width: 1, color: AppColors.borderSubtle),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCategoryTag(context),
                      const SizedBox(height: 6),
                      Text(
                        garment.name,
                        style: AppTextStyle.bold14,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (garment.color != null &&
                          garment.color!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          garment.color!,
                          style: AppTextStyle.regular12.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTag(BuildContext context) =>
      CategoryTag(label: garment.category.localizedLabel(context));
}
