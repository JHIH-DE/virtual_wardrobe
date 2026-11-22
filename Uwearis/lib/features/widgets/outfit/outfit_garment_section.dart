import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../../../data/garment.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/images/app_spinner.dart';
import '../common/labeled_divider.dart';
import '../common/overlays/error_state_widget.dart';
import '../garment/garment_list_card.dart';

/// [garments] is null until resolved; the divider shows [garmentCount]
/// meanwhile.
class OutfitGarmentSection extends StatelessWidget {
  final List<Garment>? garments;
  final int garmentCount;
  final bool isLoading;
  final ValueChanged<Garment> onGarmentTap;

  /// The last load failed: shown with [onRetry] in place of the list.
  final Object? error;
  final VoidCallback? onRetry;

  const OutfitGarmentSection({
    super.key,
    required this.garments,
    required this.garmentCount,
    required this.isLoading,
    required this.onGarmentTap,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDivider(
          label: l10n.garmentsCount(garments?.length ?? garmentCount),
        ),
        const SizedBox(height: AppDimens.cardHeaderGap),
        if (isLoading)
          const Center(child: AppSpinner())
        else if (error != null && onRetry != null)
          ErrorStateWidget(error: error!, onRetry: onRetry!)
        else if (garments != null)
          for (final (i, g) in garments!.indexed) ...[
            if (i > 0) const SizedBox(height: AppDimens.sectionSpacing),
            GarmentListCard(garment: g, onTap: () => onGarmentTap(g)),
          ],
      ],
    );
  }
}
