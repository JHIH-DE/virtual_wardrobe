import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/adaptive_side_layout.dart';
import '../../widgets/common/app_divider.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/buttons/settings_button.dart';
import '../../widgets/common/buttons/space_switch_button.dart';
import '../../widgets/common/cards/card_corner_badge.dart';

/// `ExploreShell`'s first tab, mirroring Home: brand title, a
/// "Wardrobe" switch back to `WardrobeShell`, Settings. The body is a static
/// editorial mock-up (no content backend yet), so its links and hearts are
/// visual only.
class ExploreHomePage extends StatelessWidget {
  const ExploreHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(
        title: l10n.explore,
        titleWidget: Text(
          'Uwearis',
          textScaler: TextScaler.noScaling,
          style: AppTextStyle.brandTitleToolbar,
        ),
        showBackButton: false,
        leadingWidth: 148,
        leading: Padding(
          padding: const EdgeInsets.only(left: ActionDisc.edgeInset),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SpaceSwitchButton(
              label: l10n.wardrobe,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: const [SettingsButton()],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          AppDimens.navBarClearance + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _StoryHero(l10n: l10n),
          const AppDivider(
            spacing: AppDimens.sectionSpacing,
            color: AppColors.borderStrong,
          ),
          _WorksWithWardrobe(l10n: l10n),
        ],
      ),
    );
  }
}

class _StoryHero extends StatelessWidget {
  final AppLocalizations l10n;

  const _StoryHero({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.exploreEditLabel.toUpperCase(),
          style: AppTextStyle.overline12.copyWith(
            letterSpacing: 3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimens.cardSpacing),
        AspectRatio(
          aspectRatio: 920 / 636,
          child: Image.asset(
            'assets/images/explore_01.jpg',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
        Text(l10n.exploreEditTitle, style: AppTextStyle.editorialHeadline),
        const SizedBox(height: 8),
        Text(l10n.exploreEditSubtitle, style: AppTextStyle.editorialSubtitle),
        _ExploreLink(label: l10n.exploreReadStory, showArrow: true),
      ],
    );
  }
}

class _WorksWithWardrobe extends StatelessWidget {
  final AppLocalizations l10n;

  const _WorksWithWardrobe({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveSideLayout(
          sideEdge: AdaptiveSide.trailing,
          gap: AppDimens.cardSpacing,
          stackedGap: 0,
          side: _ExploreLink(label: l10n.seeAll),
          content: Text(
            l10n.exploreWorksWithWardrobe,
            style: AppTextStyle.editorialSectionTitle,
          ),
        ),
        const SizedBox(height: AppDimens.cardSpacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final blazer = _ProductCard(
              image: 'assets/images/explore_02.jpg',
              name: l10n.exploreNavyBlazer,
              pairing: l10n.exploreNavyBlazerPairing,
              saveLabel: l10n.exploreNavSaved,
            );
            final sneakers = _ProductCard(
              image: 'assets/images/explore_03.png',
              name: l10n.exploreIvorySneakers,
              pairing: l10n.exploreIvorySneakersPairing,
              saveLabel: l10n.exploreNavSaved,
            );
            final halfWidth =
                (constraints.maxWidth - AppDimens.cardSpacing) / 2;
            final nameWidth = MediaQuery.textScalerOf(
              context,
            ).scale(_ProductCard.longestNameWordWidth);
            if (halfWidth - _ProductCard.textInset * 2 < nameWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  blazer,
                  const SizedBox(height: AppDimens.cardSpacing),
                  sneakers,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: blazer),
                  const SizedBox(width: AppDimens.cardSpacing),
                  Expanded(child: sneakers),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ExploreLink extends StatelessWidget {
  final String label;
  final bool showArrow;

  const _ExploreLink({required this.label, this.showArrow = false});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, AppDimens.minTouchTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: AppTextStyle.semibold16,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label)),
          if (showArrow) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  static const double textInset = 12;

  /// "Sneakers" at text scale 1; below this the cards stack so it isn't split.
  static const double longestNameWordWidth = 65;

  final String image;
  final String name;
  final String pairing;
  final String saveLabel;

  const _ProductCard({
    required this.image,
    required this.name,
    required this.pairing,
    required this.saveLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowResting, blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 457 / 370,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.productPhotoBackdrop,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    // Multiply turns the photos' white studio background into
                    // the backdrop colour.
                    child: Image.asset(
                      image,
                      fit: BoxFit.contain,
                      color: AppColors.productPhotoBackdrop,
                      colorBlendMode: BlendMode.multiply,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    button: true,
                    label: saveLabel,
                    child: CardCornerBadge(
                      icon: Icons.favorite_border,
                      backgroundColor: AppColors.surfaceTranslucent,
                      iconColor: AppColors.hintText,
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: const [],
                      size: 36,
                      iconSize: 20,
                      onTap: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(textInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyle.editorialCardTitle),
                const SizedBox(height: 4),
                Text(
                  pairing,
                  style: AppTextStyle.regular13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
