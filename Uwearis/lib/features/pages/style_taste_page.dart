import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/style_profile_provider.dart';
import '../../core/providers/style_taste_provider.dart';
import '../../core/services/auth_handler.dart';
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

class StyleTastePage extends ConsumerStatefulWidget {
  const StyleTastePage({super.key});

  @override
  ConsumerState<StyleTastePage> createState() => _StyleTastePageState();
}

class _StyleTastePageState extends ConsumerState<StyleTastePage> {
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    // Not autoDispose, so refresh on every visit. Post-frame: invalidating
    // inside initState touches ProviderScope before this element is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(styleTasteProfileProvider);
      ref.invalidate(styleProfileProvider);
      _watchAuthExpiry(styleTasteProfileProvider);
      _watchAuthExpiry(styleProfileProvider);
    });
  }

  /// `ErrorStateWidget` renders nothing for auth expiry, so without this the
  /// page would go blank instead of prompting to log in again.
  void _watchAuthExpiry<T>(ProviderListenable<AsyncValue<T>> provider) {
    ref.listenManual<AsyncValue<T>>(provider, (_, next) {
      if (next.hasError && next.error is AuthExpiredException && mounted) {
        AuthExpiredHandler.handle(context);
      }
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
          Text(summary, style: AppTextStyle.insightCardBody),
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
      title: l10n.styleTasteRadarCardTitle,
      subtitle: l10n.styleTasteRadarCardSubtitle,
      trailing: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showAllDescriptionsDialog,
        child: const Icon(
          Icons.info_outline,
          size: 20,
          color: AppColors.textSecondary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  /// Separate fetch, so a slow/failed request doesn't block the page.
  Widget _buildStyleProfileCard() {
    final l10n = AppLocalizations.of(context);
    final styleProfileAsync = ref.watch(styleProfileProvider);
    // An outfit can have several style tags, so the per-tag sum
    // over-counts; the center shows the real outfit total instead.
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

        // Past ~6 slices a donut stops reading at a glance; fold the rest
        // into "Other".
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
      title: l10n.styleProfileCardTitle,
      subtitle: l10n.styleProfileCardSubtitle,
      child: child,
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

  /// Static glossary covering every dimension, even ones the API didn't
  /// return.
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
