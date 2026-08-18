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

/// "How LUMI thinks you like outfits put together" — every learned
/// preference dimension plotted together on one radar chart, so the shape
/// itself reads as "this is your taste" rather than five separate bars.
/// Separate from StyleProfilePage's explicit style-tag picks: that answers
/// "what styles do I like", this answers "how do I like outfits assembled".
class StyleTastePage extends ConsumerWidget {
  const StyleTastePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preferencesAsync = ref.watch(styleTastePreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(title: l10n.styleTaste),
      body: preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          error: e,
          onRetry: () =>
              ref.read(styleTastePreferencesProvider.notifier).refresh(),
        ),
        data: (preferences) => _buildContent(context, ref, preferences),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<StyleTastePreference> preferences,
  ) {
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
        _buildAnalysisCard(context, ref),
        const SizedBox(height: 16),
        _buildRadarCard(context, preferences),
      ],
    );
  }

  Widget _buildAnalysisCard(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(styleTastePersonalitySummaryProvider);
    final outfitsAsync = ref.watch(outfitsProvider);

    return LumiInsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summaryAsync.when(
            data: (summary) => Text(summary, style: AppTextStyle.regular14),
            loading: () => const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          outfitsAsync.when(
            data: (outfits) => Text(
              l10n.styleTasteAnalysisStats(
                outfits.length,
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

  Widget _buildRadarCard(
    BuildContext context,
    List<StyleTastePreference> preferences,
  ) {
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
                  onPressed: () =>
                      _showAllDescriptionsDialog(context, preferences),
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
          Text(l10n.styleTasteKeyInsightsTitle, style: AppTextStyle.bold16),
          const SizedBox(height: 12),
          for (final preference in preferences) ...[
            _buildInsightRow(preference),
            const SizedBox(height: 10),
          ],
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

  void _showAllDescriptionsDialog(
    BuildContext context,
    List<StyleTastePreference> preferences,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.styleTasteDimensionsInfoTitle,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final preference in preferences) ...[
                Text(
                  preference.dimension.title(context),
                  style: AppTextStyle.bold14,
                ),
                const SizedBox(height: 2),
                Text(
                  preference.description ?? '',
                  style: AppTextStyle.regular13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (preference != preferences.last) const SizedBox(height: 12),
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
