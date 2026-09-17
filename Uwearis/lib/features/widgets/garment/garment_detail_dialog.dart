import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/services/garment_service.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/app_divider.dart';
import '../common/buttons/close_action_button.dart';
import '../common/cards/category_tag.dart';
import '../common/overlays/inline_error_text.dart';
import 'garment_image.dart';

/// Shows [garment]'s photo plus its category/name/color/brand/price, in a
/// centered dialog — opened by tapping a garment in an outfit's garment
/// list or in a trip day's outfit strip.
///
/// When [Garment.isDeleted] (the garment is still referenced here but has
/// since been removed from the closet), the dialog also offers "Add Back to
/// Closet" ([GarmentService.restoreGarment]) instead of just the plain
/// Close button. [show] resolves to the restored [Garment] when that
/// succeeds, or `null` for every other way the dialog closes — the caller
/// uses that to swap its own copy of the garment in place.
class GarmentDetailDialog extends StatefulWidget {
  final Garment garment;

  const GarmentDetailDialog({super.key, required this.garment});

  static Future<Garment?> show(BuildContext context, Garment garment) {
    return showDialog<Garment>(
      context: context,
      builder: (_) => GarmentDetailDialog(garment: garment),
    );
  }

  @override
  State<GarmentDetailDialog> createState() => _GarmentDetailDialogState();
}

class _GarmentDetailDialogState extends State<GarmentDetailDialog> {
  bool _restoring = false;

  Future<void> _restore() async {
    final id = widget.garment.id;
    if (_restoring || id == null) return;
    setState(() => _restoring = true);
    try {
      final restored = await GarmentService().restoreGarment(id);
      if (!mounted) return;
      Navigator.of(context).pop(restored);
    } on AuthExpiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
      await AuthExpiredHandler.handle(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToRestoreGarment),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final garment = widget.garment;
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
            const AppDivider(topSpacing: 14, bottomSpacing: 12),
            _detailRow(l10n.brand, garment.brand ?? '--'),
            const SizedBox(height: 8),
            _detailRow(
              l10n.price,
              garment.price != null
                  ? '\$${garment.price!.toStringAsFixed(0)}'
                  : '--',
            ),
            const AppDivider(topSpacing: 12, bottomSpacing: 16),
            if (garment.isDeleted) ...[
              InlineErrorText(
                message: l10n.garmentRemovedFromClosetNotice,
                padding: const EdgeInsets.only(bottom: 12),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _restoring ? null : _restore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.borderSubtle,
                    minimumSize: const Size(
                      double.infinity,
                      AppDimens.minTouchTarget,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.addBackToCloset,
                    style: AppTextStyle.regular16.copyWith(
                      color: _restoring
                          ? AppColors.hintText
                          : AppColors.textOnPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
