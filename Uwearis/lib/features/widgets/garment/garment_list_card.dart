import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../common/cards/category_tag.dart';
import 'garment_image.dart';

class GarmentListCard extends StatelessWidget {
  final Garment garment;
  final VoidCallback? onTap;

  const GarmentListCard({super.key, required this.garment, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildCard(context),
        // Soft-deleted but still referenced by the outfit; restorable from
        // GarmentDetailDialog. IgnorePointer so the icon isn't a dead zone
        // over the card's tap target.
        if (garment.isDeleted)
          const Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Icon(Icons.error, size: 26, color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: AppDimens.garmentListCardHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppDimens.cardRadius),
              ),
              child: SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  // contain: filling this narrow slot's height would crop a
                  // wide photo (e.g. shoes) to a sliver.
                  child: GarmentImage(
                    url: garment.imageUrl,
                    garmentId: garment.id,
                    memCacheWidth: 160,
                    fit: BoxFit.contain,
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
                    CategoryTag(
                      label: garment.category.localizedLabel(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      garment.name,
                      style: AppTextStyle.bold14,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (garment.color != null && garment.color!.isNotEmpty) ...[
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
    );
  }
}
