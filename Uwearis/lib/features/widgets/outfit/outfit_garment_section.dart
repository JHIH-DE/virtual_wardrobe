import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../../../data/garment.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/images/app_spinner.dart';
import '../common/labeled_divider.dart';
import '../garment/garment_list_card.dart';

/// [garments] is null until resolved; the divider shows [garmentCount]
/// meanwhile.
class OutfitGarmentSection extends StatelessWidget {
  final List<Garment>? garments;
  final int garmentCount;
  final bool isLoading;
  final ValueChanged<Garment> onGarmentTap;

  const OutfitGarmentSection({
    super.key,
    required this.garments,
    required this.garmentCount,
    required this.isLoading,
    required this.onGarmentTap,
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
        else if (garments != null)
          for (final g in garments!)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.sectionSpacing),
              child: GarmentListCard(garment: g, onTap: () => onGarmentTap(g)),
            ),
      ],
    );
  }
}
