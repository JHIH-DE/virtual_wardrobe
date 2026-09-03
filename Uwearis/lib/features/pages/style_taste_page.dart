import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/style_profile_provider.dart';
import '../../core/providers/style_taste_provider.dart';
import '../../data/style_taste.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/style_taste_dimension_localization.dart';
import '../../l10n/style_type_localization.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/cards/style_profile_pie_chart.dart';
import '../widgets/common/cards/style_taste_radar_chart.dart';
import '../widgets/common/expand_arrow_icon.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';

/// "How Uwearis thinks you like outfits put together" — every learned
/// preference dimension plotted together on one radar chart, so the shape
/// itself reads as "this is your taste" rather than five separate bars.
class StyleTastePage extends ConsumerStatefulWidget {
  const StyleTastePage({super.key});

  @override
  ConsumerState<StyleTastePage> createState() => _StyleTastePageState();
}

class _StyleTastePageState extends ConsumerState<StyleTastePage> {
  // Collapsed by default — the radar chart above already gives the at-a-
  // glance read; this is the per-dimension detail for anyone who wants it.
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    // Neither provider uses .autoDispose, so without this a return visit
    // would just keep showing whatever was fetched the first time this
    // page was ever opened — invalidate on mount so every visit reflects
    // outfits favorited/created/deleted since. Deferred to after the first
    // frame: invalidating synchronously inside initState reaches for the
    // ProviderScope's InheritedWidget before this element has finished
    // mounting, which Flutter rejects.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(styleTasteProfileProvider);
      ref.invalidate(styleProfileProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(styleTasteProfileProvider);

    var isInitialLoading = false;
    final body = profileAsync.when(
      loading: () {
        isInitialLoading = true;
        return const SizedBox.shrink();
      },
      error: (e, _) => ErrorStateWidget(
        error: e,
        onRetry: () => ref.read(styleTasteProfileProvider.notifier).refresh(),
      ),
      data: (profile) => _buildContent(profile),
    );

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppToolBar(title: l10n.styleTaste),
          body: body,
        ),
        if (isInitialLoading)
          Positioned.fill(child: LoadingOverlay(label: l10n.loading)),
      ],
    );
  }

  Widget _buildContent(StyleTasteProfile profile) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          l10n.styleTasteHeroSubtitle,
          style: AppTextStyle.regular14.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
        _buildAnalysisCard(profile.summary),
        const SizedBox(height: AppDimens.sectionSpacing),
        _buildRadarCard(profile.preferences),
        const SizedBox(height: AppDimens.sectionSpacing),
        _buildStyleProfileCard(),
      ],
    );
  }

  Widget _buildAnalysisCard(String summary) {
    final l10n = AppLocalizations.of(context);
    final outfitsAsync = ref.watch(outfitsProvider);

    return UwearisInsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: AppTextStyle.regular14),
          const SizedBox(height: 10),
          outfitsAsync.when(
            data: (outfits) => Text(
              l10n.styleTasteAnalysisStats(
                outfits.fold<int>(0, (sum, o) => sum + o.versionCount),
                outfits.where((o) => o.isFavorite).length,
              ),
              style: AppTextStyle.regular12.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarCard(List<StyleTastePreference> preferences) {
    final l10n = AppLocalizations.of(context);
    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      blurRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: SectionTitle(l10n.styleTasteRadarCardTitle)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showAllDescriptionsDialog,
                child: const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.styleTasteRadarCardSubtitle,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          LayoutBuilder(
            builder: (context, constraints) => Center(
              child: StyleTasteRadarChart(
                size: constraints.maxWidth,
                axes: [
                  for (final preference in preferences)
                    StyleTasteRadarAxis(
                      icon: preference.dimension.icon,
                      title: preference.dimension.title(context),
                      valueLabel: preference.dimension.poleLabel(
                        context,
                        preference.score,
                      ),
                      score: preference.score,
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
            child: Row(
              children: [
                Expanded(
                  child: SectionTitle(
                    l10n.styleTasteDetailsLabel,
                    style: AppTextStyle.regular16,
                  ),
                ),
                ExpandArrowIcon(expanded: _detailsExpanded),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _detailsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final preference in preferences) ...[
                    const AppDivider(topSpacing: 0, bottomSpacing: 12),
                    _buildInsightRow(preference),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// How many outfits carry each style tag, as a donut chart — part-to-
  /// whole at a glance, with the exact counts in the legend beside it (see
  /// [StyleProfilePieChart]). Independent fetch from [styleProfileProvider],
  /// same as [_buildAnalysisCard]'s outfit stats, so a slow/failed request
  /// here doesn't block the rest of the page.
  Widget _buildStyleProfileCard() {
    final l10n = AppLocalizations.of(context);
    final styleProfileAsync = ref.watch(styleProfileProvider);
    // A single outfit can carry multiple style tags, so summing per-tag
    // counts (below) over-counts actual outfits — the donut's center
    // shows the real general-outfit total instead, same source/definition
    // as _buildAnalysisCard's "N outfits analyzed" stat.
    final generalOutfitCount =
        ref
            .watch(outfitsProvider)
            .value
            ?.fold<int>(0, (sum, o) => sum + o.versionCount) ??
        0;

    return styleProfileAsync.when(
      loading: () =>
          _buildStyleProfileCardShell(const Center(child: AppSpinner())),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        final total = items.fold<int>(0, (sum, i) => sum + i.count);
        if (total == 0) {
          return _buildStyleProfileCardShell(
            Center(
              child: Text(
                l10n.noOutfitsYet,
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        // Part-to-whole only reads at a glance up to ~6 segments — past
        // that, adjacent slices blur together. Anything beyond the top 5
        // folds into one neutral "Other" bucket instead of adding a 6th+
        // categorical hue.
        const maxDirectSlices = 5;
        final top = items.take(maxDirectSlices).toList();
        final otherCount = items
            .skip(maxDirectSlices)
            .fold<int>(0, (sum, i) => sum + i.count);
        final palette = AppColors.chartCategorical;

        final slices = [
          for (var i = 0; i < top.length; i++)
            StyleProfileSlice(
              label: top[i].style?.localizedName(context) ?? top[i].rawStyle,
              count: top[i].count,
              color: palette[i % palette.length],
            ),
          if (otherCount > 0)
            StyleProfileSlice(
              label: l10n.styleProfileOther,
              count: otherCount,
              color: AppColors.chartOther,
            ),
        ];

        return _buildStyleProfileCardShell(
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StyleProfilePieChart(
                size: 120,
                slices: slices,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$generalOutfitCount', style: AppTextStyle.bold20),
                    Text(
                      l10n.navOutfits,
                      style: AppTextStyle.regular12.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final slice in slices)
                      _buildStyleProfileLegendRow(slice, total),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStyleProfileLegendRow(StyleProfileSlice slice, int total) {
    final percent = (slice.count / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              style: AppTextStyle.regular14,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percent%',
            style: AppTextStyle.bold14.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleProfileCardShell(Widget child) {
    final l10n = AppLocalizations.of(context);
    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      blurRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(l10n.styleProfileCardTitle),
          const SizedBox(height: 4),
          Text(
            l10n.styleProfileCardSubtitle,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          child,
        ],
      ),
    );
  }

  Widget _buildInsightRow(StyleTastePreference preference) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(preference.dimension.icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preference.dimension.title(context),
                style: AppTextStyle.bold14,
              ),
              const SizedBox(height: 4),
              Text(
                preference.description ?? '',
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A fixed glossary of what every dimension measures — unlike the radar
  /// card's per-dimension insight rows (Uwearis's personalized read on this
  /// user), this is the same reference text for everyone, so it always
  /// covers every dimension regardless of which ones the API happened to
  /// return data for.
  void _showAllDescriptionsDialog() {
    final l10n = AppLocalizations.of(context);
    const dimensions = StyleTasteDimension.values;
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.styleTasteDimensionsInfoTitle,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final dimension in dimensions) ...[
                Text(dimension.title(context), style: AppTextStyle.bold14),
                const SizedBox(height: 2),
                Text(
                  dimension.explanation(context),
                  style: AppTextStyle.regular13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (dimension != dimensions.last) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        primaryLabel: l10n.close,
        onPrimary: () => Navigator.pop(ctx),
      ),
    );
  }
}
