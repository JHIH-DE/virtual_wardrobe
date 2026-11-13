import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/cards/app_card_shell.dart';
import '../common/section_title.dart';

/// One suggested outfit in Garment Details' Closet Match sheet: [title] and
/// an optional "Try It On" action (hidden when [onTryOn] is null) over [child].
class GarmentOutfitIdeasCard extends StatelessWidget {
  static const double _inset = 14;

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
          Padding(
            // The pill sits centered in its touch target, so this puts its
            // visible top edge _inset from the card, matching the right.
            padding: const EdgeInsets.fromLTRB(
              _inset,
              _inset -
                  (AppDimens.minTouchTarget - AccentPillButton.pillHeight) / 2,
              _inset,
              0,
            ),
            child: ConstrainedBox(
              // Same height with or without the button.
              constraints: const BoxConstraints(
                minHeight: AppDimens.minTouchTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SectionTitle(title, style: AppTextStyle.bold18),
                  ),
                  if (onTryOn != null)
                    AccentPillButton(
                      label: AppLocalizations.of(context).tryItOn,
                      onPressed: onTryOn,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_inset, 8, _inset, _inset),
            child: child,
          ),
        ],
      ),
    );
  }
}
