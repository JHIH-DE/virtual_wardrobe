import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/magazine_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../data/magazine.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_divider.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/carousel_dots_indicator.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/buttons/pill_button.dart';
import '../../widgets/common/buttons/segmented_switch.dart';
import '../../widgets/common/buttons/settings_button.dart';
import '../../widgets/common/buttons/space_switch_button.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/labeled_divider.dart';
import '../../widgets/common/overlays/empty_state_placeholder.dart';
import '../../widgets/common/overlays/error_state_widget.dart';
import '../../widgets/magazine/magazine_credits.dart';
import '../../widgets/magazine/magazine_item_card.dart';
import '../../widgets/magazine/magazine_item_grid.dart';
import '../../widgets/magazine/magazine_network_photo.dart';
import 'editorial_story_page.dart';
import 'magazine_story_page.dart';

/// `ExploreShell`'s first tab, mirroring Home: brand title, a
/// "Wardrobe" switch back to `WardrobeShell`, Settings. The Edit is the
/// latest published magazine issue (`magazineHomeProvider`), filtered by the
/// men / women switch; the sections below it are still a static mock-up,
/// their links and hearts visual only.
class ExploreHomePage extends ConsumerStatefulWidget {
  const ExploreHomePage({super.key});

  @override
  ConsumerState<ExploreHomePage> createState() => _ExploreHomePageState();
}

class _ExploreHomePageState extends ConsumerState<ExploreHomePage> {
  MagazineAudience _audience = MagazineAudience.men;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final provider = magazineHomeFor(context, _audience);
    ref.listen(provider, (_, next) {
      if (isSettledAuthExpiry(next)) AuthExpiredHandler.handle(context);
    });
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
              label: SpaceSwitchButton.wardrobeLabel,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: const [SettingsButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(provider.future).then<void>((_) {}, onError: (_) {}),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            AppDimens.navBarClearance + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _StoryHero(
              l10n: l10n,
              home: ref.watch(provider),
              audience: _audience,
              onAudienceChanged: (a) => setState(() => _audience = a),
              onRetry: () => ref.invalidate(provider),
            ),
            const SizedBox(height: AppDimens.sectionSpacing),
            LabeledDivider(label: l10n.exploreTheSelection),
            const SizedBox(height: AppDimens.sectionSpacing),
            LabeledDivider(label: l10n.exploreLifestyle),
            const SizedBox(height: AppDimens.sectionSpacing),
            _MatchYourWardrobe(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _StoryHero extends StatelessWidget {
  static const double _editLabelSize = 36;
  static final RegExp _cjk = RegExp(r'[\u3400-\u9FFF]');

  final AppLocalizations l10n;
  final AsyncValue<MagazineHome> home;
  final MagazineAudience audience;
  final ValueChanged<MagazineAudience> onAudienceChanged;
  final VoidCallback onRetry;

  const _StoryHero({
    required this.l10n,
    required this.home,
    required this.audience,
    required this.onAudienceChanged,
    required this.onRetry,
  });

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
                child: SegmentedSwitch(
                  labels: [l10n.exploreMen, l10n.exploreWomen],
                  selectedIndex: audience == MagazineAudience.women ? 1 : 0,
                  onSelected: (i) => onAudienceChanged(
                    i == 1 ? MagazineAudience.women : MagazineAudience.men,
                  ),
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
        home.when(
          skipLoadingOnRefresh: true,
          loading: () =>
              const SizedBox(height: 240, child: Center(child: AppSpinner())),
          error: (error, _) => ErrorStateWidget(error: error, onRetry: onRetry),
          data: (home) => _buildIssue(context, home),
        ),
      ],
    );
  }

  Widget _buildIssue(BuildContext context, MagazineHome home) {
    final issue = home.issue;
    if (issue == null) {
      return EmptyStatePlaceholder(
        icon: Icons.auto_stories_outlined,
        message: l10n.exploreNoIssue,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IssueMasthead(issue: issue, kicker: _kicker(context, issue)),
        const SizedBox(height: AppDimens.sectionSpacing),
        LabeledDivider(label: l10n.exploreStyleGuide),
        const SizedBox(height: AppDimens.cardSpacing),
        if (home.stories.isEmpty)
          EmptyStatePlaceholder(message: l10n.exploreNoStories)
        else
          _EditCarousel(
            // A new list (another audience) starts again from its first page.
            key: ValueKey(home.stories.map((s) => s.id).join(',')),
            stories: home.stories,
            ctaLabel: l10n.exploreRead,
          ),
      ],
    );
  }

  /// "Issue 14 — Nov 2026", or whichever half is known.
  String? _kicker(BuildContext context, MagazineIssue issue) {
    final number = issue.issueNumber;
    final published = issue.publishedAt;
    final date = published == null
        ? null
        : DateFormat.yMMM(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(published.toLocal());
    if (number != null && date != null) {
      return l10n.exploreIssueKicker(number, date);
    }
    if (number != null) return l10n.exploreIssueNumber(number);
    return date;
  }
}

class _IssueMasthead extends StatelessWidget {
  static const double _minAspectRatio = 4.5;
  static const double _inset = 16;
  static const double _verticalInset = 10;

  final MagazineIssue issue;
  final String? kicker;

  const _IssueMasthead({required this.issue, required this.kicker});

  @override
  Widget build(BuildContext context) {
    final kicker = this.kicker;
    final title = issue.title;
    final subtitle = issue.subtitle;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final besideMountain = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.editorialPhotoRadius),
          child: Stack(
            children: [
              Positioned.fill(
                child: MagazineNetworkPhoto(
                  photo: issue.cover,
                  alignment: Alignment.centerRight,
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
                          if (kicker != null) ...[
                            Text(
                              kicker.toUpperCase(),
                              style: AppTextStyle.overline12.copyWith(
                                letterSpacing: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (title != null)
                            Text(
                              title,
                              style: AppTextStyle.editorialSectionTitle
                                  .copyWith(fontSize: 22),
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: AppTextStyle.regular13.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
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
  final List<MagazineStorySummary> stories;
  final String ctaLabel;

  const _EditCarousel({
    super.key,
    required this.stories,
    required this.ctaLabel,
  });

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
      for (final word in _latinWord.allMatches(story.title ?? '')) {
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

  void _open(MagazineStorySummary story) {
    Navigator.push(
      context,
      story.format == MagazineFormat.story
          ? EditorialStoryPage.route(storyId: story.id, summary: story)
          : MaterialPageRoute<void>(
              builder: (_) =>
                  MagazineStoryPage(storyId: story.id, title: story.title),
            ),
    );
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
                    onRead: () {},
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
                    onRead: () => _open(stories[index]),
                  ),
                ),
              ),
              if (stories.length > 1)
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
  final MagazineStorySummary story;
  final String ctaLabel;
  final double width;
  final bool besideSubject;
  final VoidCallback onRead;

  const _StoryPage({
    required this.story,
    required this.ctaLabel,
    required this.width,
    required this.besideSubject,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRead,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The card's own image is framed by its focal point; a cover
          // standing in keeps its subject right of the copy.
          story.card == null
              ? MagazineNetworkPhoto(
                  photo: story.cover,
                  alignment: const Alignment(0.45, 0),
                )
              : MagazineNetworkPhoto(photo: story.card),
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
              onRead: onRead,
            ),
          ),
        ],
      ),
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

  final MagazineStorySummary story;
  final String ctaLabel;
  final double width;
  final bool besideSubject;
  final VoidCallback onRead;

  const _StoryCopy({
    required this.story,
    required this.ctaLabel,
    required this.width,
    required this.besideSubject,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    const onPhoto = AppColors.textOnPrimary;
    final title = story.title;
    final subtitle = story.subtitle;
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
                if (story.isSponsored) ...[
                  MagazineSponsorLabel(story: story, onPhoto: true),
                  const SizedBox(height: 8),
                ],
                if (title != null) Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: AppTextStyle.editorialSubtitle.copyWith(
                      fontSize: 16,
                      color: onPhoto,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                PillButton(label: ctaLabel, onPressed: onRead),
              ],
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

  MagazineItemCard _card(String image, String name, String pairing) =>
      MagazineItemCard(
        photo: Image.asset(
          image,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        name: name,
        detail: pairing,
        saveLabel: l10n.exploreNavSaved,
        onSave: () {},
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDivider(label: l10n.exploreMatchYourWardrobe),
        const SizedBox(height: AppDimens.cardSpacing),
        MagazineItemGrid(
          cards: [
            _card(
              'assets/images/explore_04.png',
              l10n.exploreNavyBlazer,
              l10n.exploreNavyBlazerPairing,
            ),
            _card(
              'assets/images/explore_05.png',
              l10n.exploreIvorySneakers,
              l10n.exploreIvorySneakersPairing,
            ),
          ],
        ),
      ],
    );
  }
}
