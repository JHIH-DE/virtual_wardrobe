import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/cards/category_tag.dart';
import '../common/buttons/close_action_button.dart';
import 'garment_image.dart';

/// Shows [garment]'s photo plus its category/name/color/brand/price, in a
/// centered dialog — replaces jumping to a bare full-screen image when
/// tapping a garment in an outfit's garment list.
class GarmentDetailDialog extends StatelessWidget {
  final Garment garment;

  const GarmentDetailDialog({super.key, required this.garment});

  static Future<void> show(BuildContext context, Garment garment) {
    return showDialog<void>(
      context: context,
      builder: (_) => GarmentDetailDialog(garment: garment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GarmentImage(
                  url: garment.imageUrl,
                  garmentId: garment.id,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CategoryTag(label: garment.category.localizedLabel(context)),
            const SizedBox(height: 10),
            Text(garment.name, style: AppTextStyle.bold20),
            if (garment.color != null && garment.color!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                garment.color!,
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 12),
            _detailRow(l10n.brand, garment.brand ?? '--'),
            const SizedBox(height: 8),
            _detailRow(
              l10n.price,
              garment.price != null
                  ? '\$${garment.price!.toStringAsFixed(0)}'
                  : '--',
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 16),
            Center(
              child: CloseActionButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyle.bold14),
        const SizedBox(width: 8),
        Container(width: 1, height: 14, color: AppColors.borderSubtle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
