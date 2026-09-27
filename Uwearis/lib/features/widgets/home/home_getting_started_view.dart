import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/cards/app_card_shell.dart';

/// The Getting Started content [HomePage] shows in place of Today's
/// Outfit/Upcoming Trip/Recently Added for a user who hasn't finished the
/// minimum setup yet — see `home_page.dart`'s `_isGettingStarted` for the
/// completion rule this reflects. A complete initial flow is About You +
/// Profile Photo + Full-Body Photo + Closet + creating the first outfit —
/// this view shows all five as one checklist card, with a single CTA below
/// it that always targets whichever step is next (see
/// [_buildChecklistCard]/[_buildCtaButton]), rather than swapping between
/// separate step screens. [HomePage] omits its date/weather header for this
/// state (nothing there
/// is relevant before setup is done) and renders this as one section of its
/// existing scroll body, not a full-screen replacement, so it owns no
/// scroll container, outer page padding, or bottom nav-bar clearance of its
/// own — the main nav bar stays exactly as it is in normal Home.
///
/// Purely presentational — [HomePage] owns every provider read and
/// navigation call and passes down plain booleans + callbacks, so this
/// widget never touches a service/provider directly (see CLAUDE.md's
/// "Widget reuse and extraction" on keeping business logic out of
/// presentational widgets).
class HomeGettingStartedView extends StatelessWidget {
  /// Whether Account's four required fields (name/gender/birthday/home
  /// location) are all filled in — see `AccountPage`'s own
  /// `_hasRequiredAboutYouFields`.
  final bool hasAboutYou;
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

  /// Opens `AccountPage` (in its onboarding mode) — the first sub-step of
  /// this profile step. `AccountPage` itself continues on to the existing
  /// My Virtual Model flow (`MyVirtualModelPage`, which owns both
  /// reference-photo upload flows) once its own required fields are filled
  /// in, so this view never re-implements either of those flows.
  final VoidCallback onGetStarted;

  /// Opens the existing Add Clothing flow (`GarmentUploadHelper`).
  final VoidCallback onAddClothing;

  /// Opens the existing Add Outfit flow — same action as normal Home's own
  /// "Create Outfit" trigger (`HomePage._openAddOutfit`).
  final VoidCallback onCreateOutfit;

  const HomeGettingStartedView({
    super.key,
    required this.hasAboutYou,
    required this.hasProfilePhoto,
    required this.hasFullBodyPhoto,
    required this.hasTop,
    required this.hasBottom,
    required this.hasShoes,
    required this.onGetStarted,
    required this.onAddClothing,
    required this.onCreateOutfit,
  });

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
        const SizedBox(height: AppDimens.sectionSpacing * 2),
        _buildChecklistCard(context, l10n),
      ],
    );
  }

  /// One checklist covering the whole initial flow — About You, My Virtual
  /// Model, Top, Bottom, Shoes, then creating the first outfit — instead of
  /// swapping between three separate step screens. [onCreateOutfit]'s row
  /// has no "done" state of its own to show as checked: [HomePage] only
  /// renders this whole view while [_isGettingStarted] is true, and that
  /// stays true until the outfit is actually created, so this row is always
  /// the last one pending whenever it's reachable (i.e. once every row
  /// above it is done). The CTA lives inside the same card, right-aligned
  /// below the checklist, rather than as a separate full-width element
  /// beneath it.
  Widget _buildChecklistCard(BuildContext context, AppLocalizations l10n) {
    return AppCardShell(
      child: Column(
        children: [
          _ChecklistRow(
            label: l10n.gettingStartedAboutYouLabel,
            done: hasAboutYou,
          ),
          const SizedBox(height: 14),
          _ChecklistRow(
            label: l10n.myVirtualModelTitle,
            done: hasProfilePhoto && hasFullBodyPhoto,
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          _ChecklistRow(label: l10n.createOutfit, done: false),
          const SizedBox(height: AppDimens.sectionSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_buildCtaButton(l10n)],
          ),
        ],
      ),
    );
  }

  /// One CTA that always targets whichever step is next, rather than a
  /// separate button per step screen. Styled like [AppDialog]'s filled
  /// accent primary button (same fill/radius/elevation/border/text
  /// treatment) rather than [AccentPillButton] — this sits at the bottom of
  /// a content card as the checklist's one call to action, the same role
  /// that button plays at the bottom of a dialog, not a lightweight
  /// secondary affordance next to a section header. It hugs its label
  /// instead of stretching full-width, since it's right-aligned beside the
  /// checklist rather than stacked alone.
  ///
  /// The label only ever says "Get Started" (before [hasAboutYou] — the
  /// checklist's first row — is done) or "Next" (every step after); it
  /// doesn't spell out which specific action comes next the way the
  /// checklist rows themselves already do. [onPressed] still targets the
  /// right callback for whichever step is actually next.
  Widget _buildCtaButton(AppLocalizations l10n) {
    final VoidCallback onPressed;
    if (!_profileReady) {
      onPressed = onGetStarted;
    } else if (!_closetReady) {
      onPressed = onAddClothing;
    } else {
      onPressed = onCreateOutfit;
    }
    return _AccentActionButton(
      label: hasAboutYou
          ? l10n.gettingStartedNextButton
          : l10n.gettingStartedGetStartedButton,
      onPressed: onPressed,
    );
  }
}

/// The filled accent button from [AppDialog]'s own `_buildPrimaryButton`,
/// re-shaped to hug its label instead of stretching full-width — that
/// version is a private build method on a `StatefulWidget`, not a shared
/// component, so this reproduces its exact fill/radius/elevation/border/
/// text recipe rather than importing it.
class _AccentActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AccentActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        // Matches BottomActionButton's/AppDialog's primary button height —
        // width hugs the label since this button sits right-aligned, not
        // stretched full-width like AppDialog's own.
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        side: const BorderSide(color: AppColors.borderOnDark, width: 1.5),
      ),
      child: Text(
        label,
        style: AppTextStyle.regular16.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
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
