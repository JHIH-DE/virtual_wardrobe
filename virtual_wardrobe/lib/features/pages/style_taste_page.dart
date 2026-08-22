import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/style_taste_provider.dart';
import '../../data/style_taste.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/style_taste_dimension_localization.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/lumi_insight_card.dart';
import '../widgets/common/cards/style_taste_radar_chart.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/common/overlays/loading_overlay.dart';

/// "How LUMI thinks you like outfits put together" — every learned
/// preference dimension plotted together on one radar chart, so the shape
/// itself reads as "this is your taste" rather than five separate bars.
/// Separate from StyleProfilePage's explicit style-tag picks: that answers
/// "what styles do I like", this answers "how do I like outfits assembled".
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
        const SizedBox(height: 16),
        _buildAnalysisCard(profile.summary),
        const SizedBox(height: 16),
        _buildRadarCard(profile.preferences),
      ],
    );
  }

  Widget _buildAnalysisCard(String summary) {
    final l10n = AppLocalizations.of(context);
    final outfitsAsync = ref.watch(outfitsProvider);

    return LumiInsightCard(
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
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarCard(List<StyleTastePreference> preferences) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.styleTasteRadarCardTitle,
                  style: AppTextStyle.bold18,
                ),
              ),
              Transform.translate(
                offset: const Offset(8, 0),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: _showAllDescriptionsDialog,
                ),
              ),
            ],
          ),
          Text(
            l10n.styleTasteRadarCardSubtitle,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
            child: Row(
              children: [
                Expanded(child: Text(l10n.details, style: AppTextStyle.bold16)),
                AnimatedRotation(
                  turns: _detailsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.icon,
                  ),
                ),
              ],
            ),
          ),
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
                    _buildInsightRow(preference),
                    const SizedBox(height: 10),
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

  Widget _buildInsightRow(StyleTastePreference preference) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.interactiveArea,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              preference.dimension.icon,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              preference.description ?? '',
              style: AppTextStyle.regular14,
            ),
          ),
        ],
      ),
    );
  }

  /// A fixed glossary of what every dimension measures — unlike the radar
  /// card's per-dimension insight rows (LUMI's personalized read on this
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
