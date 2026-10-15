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
import '../common/cards/category_tag.dart';
import '../common/overlays/error_dialog.dart';
import '../common/overlays/inline_error_text.dart';
import 'garment_image.dart';

/// Tap-anywhere-to-close garment summary dialog. A soft-deleted garment also
/// gets "Add Back to Closet", which wins the gesture arena over the close
/// tap. [show] resolves to the restored [Garment], or null otherwise.
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
      showErrorDialog(
        context,
        message: AppLocalizations.of(context).failedToRestoreGarment,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
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
              if (_hasDetailRows(garment)) ...[
                const AppDivider(topSpacing: 14, bottomSpacing: 12),
                if (garment.brand != null && garment.brand!.isNotEmpty) ...[
                  _detailRow(l10n.brand, garment.brand!),
                  if (garment.price != null) const SizedBox(height: 8),
                ],
                if (garment.price != null)
                  _detailRow(
                    l10n.price,
                    '\$${garment.price!.toStringAsFixed(0)}',
                  ),
                const AppDivider(topSpacing: 12, bottomSpacing: 16),
              ],
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
                      style: AppTextStyle.medium16.copyWith(
                        color: _restoring
                            ? AppColors.hintText
                            : AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasDetailRows(Garment garment) =>
      (garment.brand != null && garment.brand!.isNotEmpty) ||
      garment.price != null;

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
