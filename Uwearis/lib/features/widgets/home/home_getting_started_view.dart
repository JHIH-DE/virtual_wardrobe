import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/cards/app_card_shell.dart';

/// Home's setup checklist for a user who hasn't finished onboarding (see
/// `HomePage._isGettingStarted`). Rendered inside Home's scroll body, so it
/// owns no scroll container, page padding or nav-bar clearance.
class HomeGettingStartedView extends StatelessWidget {
  /// Name, gender, birthday and home location are all filled in.
  final bool hasAboutYou;
  final bool hasProfilePhoto;
  final bool hasFullBodyPhoto;

  /// At least one active garment in each category.
  final bool hasTop;
  final bool hasBottom;
  final bool hasShoes;

  /// An established user can land here (incomplete closet) with outfits.
  final bool hasCreatedOutfit;

  /// Opens Account in onboarding mode, which continues on to My Virtual
  /// Model for the two reference photos.
  final VoidCallback onGetStarted;

  final VoidCallback onAddClothing;
  final VoidCallback onCreateOutfit;

  const HomeGettingStartedView({
    super.key,
    required this.hasAboutYou,
    required this.hasProfilePhoto,
    required this.hasFullBodyPhoto,
    required this.hasTop,
    required this.hasBottom,
    required this.hasShoes,
    required this.hasCreatedOutfit,
    required this.onGetStarted,
    required this.onAddClothing,
    required this.onCreateOutfit,
  });

  static const double _cardPadding = 20;
  static const double _rowGap = 16;

  /// [AccentPillButton]'s 44px tap box extends 8px past its 28px pill on
  /// each side; subtracted so the visible gaps match [_cardPadding].
  static const double _pillTapInset = 8;

  bool get _profileReady => hasAboutYou && hasProfilePhoto && hasFullBodyPhoto;
  bool get _closetReady => hasTop && hasBottom && hasShoes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.gettingStartedWelcomeTitle,
          textAlign: TextAlign.center,
          style: AppTextStyle.bold24,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gettingStartedWelcomeSubtitle,
          textAlign: TextAlign.center,
          style: AppTextStyle.regular14.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppDimens.titleGap),
        _buildChecklistCard(context, l10n),
      ],
    );
  }

  Widget _buildChecklistCard(BuildContext context, AppLocalizations l10n) {
    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(
        _cardPadding,
        _cardPadding,
        _cardPadding,
        _cardPadding - _pillTapInset,
      ),
      child: Column(
        children: [
          _ChecklistRow(
            label: l10n.gettingStartedAboutYouLabel,
            done: hasAboutYou,
          ),
          const SizedBox(height: _rowGap),
          _ChecklistRow(
            label: l10n.myVirtualModelTitle,
            done: hasProfilePhoto && hasFullBodyPhoto,
          ),
          const SizedBox(height: _rowGap),
          _ChecklistRow(
            label: GarmentCategory.top.localizedLabel(context),
            done: hasTop,
          ),
          const SizedBox(height: _rowGap),
          _ChecklistRow(
            label: GarmentCategory.bottom.localizedLabel(context),
            done: hasBottom,
          ),
          const SizedBox(height: _rowGap),
          _ChecklistRow(
            label: GarmentCategory.shoes.localizedLabel(context),
            done: hasShoes,
          ),
          const SizedBox(height: _rowGap),
          _ChecklistRow(label: l10n.createOutfit, done: hasCreatedOutfit),
          const SizedBox(height: _cardPadding - _pillTapInset),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_buildCtaButton(l10n)],
          ),
        ],
      ),
    );
  }

  /// One CTA that targets whichever step is next.
  Widget _buildCtaButton(AppLocalizations l10n) {
    final VoidCallback onPressed;
    if (!_profileReady) {
      onPressed = onGetStarted;
    } else if (!_closetReady) {
      onPressed = onAddClothing;
    } else {
      onPressed = onCreateOutfit;
    }
    return AccentPillButton(
      label: hasAboutYou
          ? l10n.gettingStartedNextButton
          : l10n.gettingStartedGetStartedButton,
      onPressed: onPressed,
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool done;

  const _ChecklistRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 22,
          color: done ? AppColors.success : AppColors.hintText,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyle.medium16)),
      ],
    );
  }
}
