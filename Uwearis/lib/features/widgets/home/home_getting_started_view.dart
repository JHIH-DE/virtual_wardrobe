import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/cards/app_card_shell.dart';
import '../common/labeled_divider.dart';

/// The Getting Started content [HomePage] shows in place of Today's
/// Outfit/Upcoming Trip/Recently Added for a user who hasn't finished the
/// minimum setup yet — see `home_page.dart`'s `_isGettingStarted` for the
/// completion rule this reflects. A complete initial flow is Profile Photo +
/// Full-Body Photo + Closet + creating the first outfit — this view walks
/// through all four in that order, without acting like a multi-page
/// onboarding wizard: only the current relevant step is shown. The date/
/// weather header above it, and the main nav bar, stay exactly as they are
/// in normal Home — [HomePage] renders this as one section of its existing
/// scroll body, not a full-screen replacement, so it owns no scroll
/// container, outer page padding, or bottom nav-bar clearance of its own.
///
/// Purely presentational — [HomePage] owns every provider read and
/// navigation call and passes down plain booleans + callbacks, so this
/// widget never touches a service/provider directly (see CLAUDE.md's
/// "Widget reuse and extraction" on keeping business logic out of
/// presentational widgets).
class HomeGettingStartedView extends StatelessWidget {
  final bool hasProfilePhoto;
  final bool hasFullBodyPhoto;

  /// Whether the closet already has at least one active garment in each of
  /// these three categories — the closet step's completion rule, needed
  /// individually (rather than one aggregate bool) so its checklist can show
  /// per-category progress the same way the profile step does for its two
  /// reference photos.
  final bool hasTop;
  final bool hasBottom;
  final bool hasShoes;

  /// Opens the existing Try-On Profile flow (`TryonProfilePage`), which
  /// already owns both reference-photo upload flows — this view never
  /// re-implements photo picking/upload.
  final VoidCallback onOpenTryOnProfile;

  /// Opens the existing Add Clothing flow (`GarmentUploadHelper`).
  final VoidCallback onAddClothing;

  /// Opens the existing Add Outfit flow — same action as normal Home's own
  /// "Create Outfit" trigger (`HomePage._openAddOutfit`).
  final VoidCallback onCreateOutfit;

  const HomeGettingStartedView({
    super.key,
    required this.hasProfilePhoto,
    required this.hasFullBodyPhoto,
    required this.hasTop,
    required this.hasBottom,
    required this.hasShoes,
    required this.onOpenTryOnProfile,
    required this.onAddClothing,
    required this.onCreateOutfit,
  });

  bool get _profileReady => hasProfilePhoto && hasFullBodyPhoto;
  bool get _closetReady => hasTop && hasBottom && hasShoes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        LabeledDivider(label: l10n.gettingStartedSectionLabel),
        const SizedBox(height: AppDimens.sectionSpacing),
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
        const SizedBox(height: AppDimens.sectionSpacing * 2),
        _buildCurrentStep(context, l10n),
      ],
    );
  }

  Widget _buildCurrentStep(BuildContext context, AppLocalizations l10n) {
    if (!_profileReady) return _buildProfileStep(l10n);
    if (!_closetReady) return _buildClosetStep(context, l10n);
    return _buildFirstOutfitStep(l10n);
  }

  Widget _buildProfileStep(AppLocalizations l10n) {
    return Column(
      children: [
        AppCardShell(
          child: Column(
            children: [
              _ChecklistRow(
                label: l10n.gettingStartedProfilePhotoLabel,
                done: hasProfilePhoto,
              ),
              const SizedBox(height: 14),
              _ChecklistRow(
                label: l10n.gettingStartedFullBodyPhotoLabel,
                done: hasFullBodyPhoto,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
        AccentPillButton(
          label: l10n.gettingStartedGetStartedButton,
          icon: Icons.arrow_forward_rounded,
          onPressed: onOpenTryOnProfile,
        ),
      ],
    );
  }

  /// Requires one active garment each in Top/Bottom/Shoes — enough category
  /// coverage to actually assemble an outfit — shown as the same ○/✓
  /// checklist shape as [_buildProfileStep], rather than just "closet
  /// non-empty", so the user knows exactly what's still missing.
  Widget _buildClosetStep(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.gettingStartedBuildClosetTitle,
          textAlign: TextAlign.center,
          style: AppTextStyle.bold18,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gettingStartedBuildClosetSubtitle,
          textAlign: TextAlign.center,
          style: AppTextStyle.regular14.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
        AppCardShell(
          child: Column(
            children: [
              _ChecklistRow(
                label: GarmentCategory.top.localizedLabel(context),
                done: hasTop,
              ),
              const SizedBox(height: 14),
              _ChecklistRow(
                label: GarmentCategory.bottom.localizedLabel(context),
                done: hasBottom,
              ),
              const SizedBox(height: 14),
              _ChecklistRow(
                label: GarmentCategory.shoes.localizedLabel(context),
                done: hasShoes,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
        AccentPillButton(
          label: l10n.quickActionAddClothing,
          icon: Icons.add,
          onPressed: onAddClothing,
        ),
      ],
    );
  }

  /// The final Getting Started step — same copy/CTA as before this became a
  /// dedicated step (see git history), just relocated here instead of
  /// living as a normal-Home contextual empty state, since creating the
  /// first outfit is now part of the initial flow rather than something a
  /// "graduated" user can skip.
  Widget _buildFirstOutfitStep(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.gettingStartedReadyForFirstLookTitle,
          textAlign: TextAlign.center,
          style: AppTextStyle.bold18,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gettingStartedReadyForFirstLookSubtitle,
          textAlign: TextAlign.center,
          style: AppTextStyle.regular14.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
        AccentPillButton(
          label: l10n.createOutfit,
          icon: Icons.add,
          onPressed: onCreateOutfit,
        ),
      ],
    );
  }
}

/// A single "○ / ✓" checklist line — deliberately not [CardCornerBadge]
/// (that's a photo-overlay/list-row action badge, a different product
/// concept; see CLAUDE.md's "Corner badges") — but it follows the same
/// resting-state color convention: neutral/incomplete is
/// [AppColors.hintText], done switches to [AppColors.accent].
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
          color: done ? AppColors.accent : AppColors.hintText,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyle.medium16)),
      ],
    );
  }
}
