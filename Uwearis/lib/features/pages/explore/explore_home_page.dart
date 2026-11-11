import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/edit_story.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_divider.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/carousel_dots_indicator.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/buttons/pill_button.dart';
import '../../widgets/common/buttons/settings_button.dart';
import '../../widgets/common/buttons/space_switch_button.dart';
import '../../widgets/common/cards/card_corner_badge.dart';
import '../../widgets/common/labeled_divider.dart';

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
          const SizedBox(height: AppDimens.sectionSpacing),
          LabeledDivider(label: l10n.exploreTheSelection),
          const SizedBox(height: AppDimens.sectionSpacing),
          LabeledDivider(label: l10n.exploreLifestyle),
          const SizedBox(height: AppDimens.sectionSpacing),
          _MatchYourWardrobe(l10n: l10n),
        ],
      ),
    );
  }
}

class _StoryHero extends StatelessWidget {
  static const double _editLabelSize = 36;
  static final RegExp _cjk = RegExp(r'[\u3400-\u9FFF]');

  final AppLocalizations l10n;

  const _StoryHero({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppDimens.cardSpacing,
            runSpacing: 8,
            children: [
              Padding(
                // Drops the switch's top edge level with the label's glyph
                // top (not the font's ascender); CJK glyphs stand taller.
                padding: EdgeInsets.only(
                  top:
                      _editLabelSize *
                      (_cjk.hasMatch(l10n.exploreEditLabel) ? 0.085 : 0.2),
                ),
                child: _GenderSwitch(
                  men: l10n.exploreMen,
                  women: l10n.exploreWomen,
                ),
              ),
              Text(
                l10n.exploreEditLabel.toUpperCase(),
                style: AppTextStyle.overline12.copyWith(
                  fontSize: _editLabelSize,
                  height: 1,
                  letterSpacing: 3,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const AppDivider(
          topSpacing: 4,
          bottomSpacing: AppDimens.cardSpacing,
          color: AppColors.textPrimary,
        ),
        _IssueMasthead(l10n: l10n),
        const SizedBox(height: AppDimens.sectionSpacing),
        LabeledDivider(label: l10n.exploreStyleGuide),
        const SizedBox(height: AppDimens.cardSpacing),
        _EditCarousel(
          stories: EditStory.bundled(l10n),
          ctaLabel: l10n.exploreRead,
        ),
      ],
    );
  }
}

class _IssueMasthead extends StatelessWidget {
  static const double _minAspectRatio = 4.5;
  static const double _inset = 16;
  static const double _verticalInset = 10;

  final AppLocalizations l10n;

  const _IssueMasthead({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final besideMountain = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.editorialPhotoRadius),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/explore_00.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.mastheadSky,
                        AppColors.mastheadSky.withValues(alpha: 0),
                      ],
                      stops: besideMountain
                          ? const [0.45, 0.7]
                          : const [0.7, 1],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: width,
                  minHeight: width / _minAspectRatio,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _inset,
                    vertical: _verticalInset,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: besideMountain
                            ? width * 0.55
                            : width - _inset * 2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.exploreIssueKicker.toUpperCase(),
                            style: AppTextStyle.overline12.copyWith(
                              letterSpacing: 1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.exploreIssueTitle,
                            style: AppTextStyle.editorialSectionTitle.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.exploreIssueSubtitle,
                            style: AppTextStyle.regular13.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditCarousel extends StatefulWidget {
  final List<EditStory> stories;
  final String ctaLabel;

  const _EditCarousel({required this.stories, required this.ctaLabel});

  @override
  State<_EditCarousel> createState() => _EditCarouselState();
}

class _EditCarouselState extends State<_EditCarousel> {
  /// CJK wraps between any characters, so only Latin words can break.
  static final RegExp _latinWord = RegExp(r"[A-Za-z0-9\u00C0-\u024F'’,.]+");

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _longestTitleWordWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final story in widget.stories) {
      for (final word in _latinWord.allMatches(story.title)) {
        final painter = TextPainter(
          text: TextSpan(text: word[0], style: _StoryCopy.titleStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.stories;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Beside the subject only while the copy fits there without
        // breaking a word; otherwise it takes the full width over a darker
        // scrim.
        final besideSubject =
            MediaQuery.textScalerOf(context).scale(1) <= 1.3 &&
            _longestTitleWordWidth(context) <=
                constraints.maxWidth * _StoryCopy.besideSubjectWidthFactor;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.editorialPhotoRadius),
          child: Stack(
            children: [
              // Invisible copies of every story's text size the carousel to
              // the tallest one, so no page's copy is cut off.
              for (final story in stories)
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: _StoryCopy(
                    story: story,
                    ctaLabel: widget.ctaLabel,
                    width: constraints.maxWidth,
                    besideSubject: besideSubject,
                  ),
                ),
              Positioned.fill(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: stories.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) => _StoryPage(
                    story: stories[index],
                    ctaLabel: widget.ctaLabel,
                    width: constraints.maxWidth,
                    besideSubject: besideSubject,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: _StoryCopy.dotsBottom,
                child: IgnorePointer(
                  child: CarouselDotsIndicator(
                    count: stories.length,
                    currentIndex: _index,
                    variant: CarouselDotsVariant.onPhoto,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StoryPage extends StatelessWidget {
  final EditStory story;
  final String ctaLabel;
  final double width;
  final bool besideSubject;

  const _StoryPage({
    required this.story,
    required this.ctaLabel,
    required this.width,
    required this.besideSubject,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          story.imageAsset,
          fit: BoxFit.cover,
          alignment: const Alignment(0.45, 0),
          excludeFromSemantics: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.overlayMedium,
                AppColors.overlayMedium.withValues(alpha: 0),
              ],
              stops: besideSubject ? const [0.2, 0.7] : const [0.6, 1],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: _StoryCopy(
            story: story,
            ctaLabel: ctaLabel,
            width: width,
            besideSubject: besideSubject,
          ),
        ),
      ],
    );
  }
}

class _StoryCopy extends StatelessWidget {
  static const double _photoAspectRatio = 920 / 636;
  static const double _inset = 20;
  static const double dotsBottom = 12;
  static const double besideSubjectWidthFactor = 0.55;

  static TextStyle get titleStyle => AppTextStyle.editorialHeadline.copyWith(
    fontSize: 28,
    color: AppColors.textOnPrimary,
  );

  /// Keeps the button clear of the page dots.
  static const double _bottomInset = dotsBottom + 20 + 4;

  final EditStory story;
  final String ctaLabel;
  final double width;
  final bool besideSubject;

  const _StoryCopy({
    required this.story,
    required this.ctaLabel,
    required this.width,
    required this.besideSubject,
  });

  @override
  Widget build(BuildContext context) {
    const onPhoto = AppColors.textOnPrimary;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: width / _photoAspectRatio,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _inset,
          _inset,
          _inset,
          _bottomInset,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: besideSubject
                  ? width * besideSubjectWidthFactor
                  : width - _inset * 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (story.kicker case final kicker?) ...[
                  Text(
                    kicker.toUpperCase(),
                    style: AppTextStyle.overline12.copyWith(
                      letterSpacing: 2,
                      color: onPhoto,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(story.title, style: titleStyle),
                const SizedBox(height: 8),
                Text(
                  story.subtitle,
                  style: AppTextStyle.editorialSubtitle.copyWith(
                    fontSize: 16,
                    color: onPhoto,
                  ),
                ),
                const SizedBox(height: 12),
                PillButton(label: ctaLabel, onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual only until Explore has a content backend.
class _GenderSwitch extends StatefulWidget {
  final String men;
  final String women;

  const _GenderSwitch({required this.men, required this.women});

  @override
  State<_GenderSwitch> createState() => _GenderSwitchState();
}

class _GenderSwitchState extends State<_GenderSwitch> {
  static const double _height = 32;

  bool _isMen = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: _height),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _segment(widget.men, selected: _isMen, isMen: true),
            _segment(widget.women, selected: !_isMen, isMen: false),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, {required bool selected, required bool isMen}) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _isMen = isMen),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: AppTextStyle.semibold14.copyWith(
              color: selected
                  ? AppColors.textOnPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchYourWardrobe extends StatelessWidget {
  final AppLocalizations l10n;

  const _MatchYourWardrobe({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDivider(label: l10n.exploreMatchYourWardrobe),
        const SizedBox(height: AppDimens.cardSpacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final blazer = _ProductCard(
              image: 'assets/images/explore_04.png',
              name: l10n.exploreNavyBlazer,
              pairing: l10n.exploreNavyBlazerPairing,
              saveLabel: l10n.exploreNavSaved,
            );
            final sneakers = _ProductCard(
              image: 'assets/images/explore_05.png',
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
