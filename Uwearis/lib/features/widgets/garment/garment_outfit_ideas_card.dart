import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/cards/app_card_shell.dart';

/// One suggested outfit in Garment Details' Closet Match sheet. Laid out
/// like TripCard: a header block — [title] plus the optional "Try It On"
/// action — on the same interactive-area tint as TripCard's "View Plan"
/// strip, split by a hairline divider from [child], the outfit's garment
/// row. [onTryOn] null hides the action.
class GarmentOutfitIdeasCard extends StatelessWidget {
  final String title;
  final VoidCallback? onTryOn;
  final Widget child;

  const GarmentOutfitIdeasCard({
    super.key,
    required this.title,
    this.onTryOn,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.interactiveArea,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            // AccentPillButton's full tap-target height, with or without
            // the button, so every card's header is the same height.
            height: AppDimens.minTouchTarget + 4,
            child: Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyle.bold16)),
                if (onTryOn != null)
                  AccentPillButton(
                    label: AppLocalizations.of(context).tryItOn,
                    icon: Icons.checkroom_outlined,
                    onPressed: onTryOn,
                  ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.dividerSubtle,
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}
