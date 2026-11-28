import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'buttons/action_button.dart';
import 'cards/app_card_shell.dart';

/// Home's setup checklist for a user who hasn't finished onboarding (see
/// `WardrobeHomePage._isGettingStarted`). Rendered inside Home's scroll body, so it
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

  /// Opens Account in onboarding mode, which continues on to My Outfit
  /// Profile for the two reference photos.
  final VoidCallback onGetStarted;

  /// Opens My Outfit Profile directly once About You is already done.
  final VoidCallback onSetUpVirtualModel;

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
    required this.onSetUpVirtualModel,
    required this.onAddClothing,
    required this.onCreateOutfit,
  });

  static const double _cardPadding = 20;
  static const double _rowGap = 16;

  bool get _virtualModelReady => hasProfilePhoto && hasFullBodyPhoto;
  bool get _closetReady => hasTop && hasBottom && hasShoes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.gettingStartedWelcomeTitle,
          style: AppTextStyle.bold24.copyWith(
            fontSize: 30,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.gettingStartedWelcomeSubtitle,
          style: AppTextStyle.regular16.copyWith(
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
      padding: const EdgeInsets.all(_cardPadding),
      child: Column(
        children: [
          _ChecklistRow(
            label: l10n.gettingStartedAboutYouLabel,
            done: hasAboutYou,
          ),
          const SizedBox(height: _rowGap),
          _ChecklistRow(
            label: l10n.myVirtualModelTitle,
            done: _virtualModelReady,
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
          const SizedBox(height: _cardPadding),
          _buildCtaButton(l10n),
        ],
      ),
    );
  }

  /// One CTA that targets whichever step is next.
  Widget _buildCtaButton(AppLocalizations l10n) {
    final VoidCallback onPressed;
    if (!hasAboutYou) {
      onPressed = onGetStarted;
    } else if (!_virtualModelReady) {
      onPressed = onSetUpVirtualModel;
    } else if (!_closetReady) {
      onPressed = onAddClothing;
    } else {
      onPressed = onCreateOutfit;
    }
    return ActionButton(
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
