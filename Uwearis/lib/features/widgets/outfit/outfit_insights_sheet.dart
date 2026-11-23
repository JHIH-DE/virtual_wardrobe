import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/outfits_provider.dart';
import '../../../core/providers/style_profile_provider.dart';
import '../../../core/providers/style_taste_provider.dart';
import '../../../core/providers/temperature_coverage_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../data/style_taste.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/style_taste_dimension_localization.dart';
import '../../../l10n/style_type_localization.dart';
import '../common/app_divider.dart';
import '../common/buttons/segmented_switch.dart';
import '../common/cards/app_card_shell.dart';
import '../common/info_glyph.dart';
import '../common/cards/style_profile_pie_chart.dart';
import '../common/cards/style_taste_radar_chart.dart';
import '../common/images/app_spinner.dart';
import '../common/overlays/app_dialog.dart';
import '../common/overlays/error_state_widget.dart';
import '../common/overlays/loading_overlay.dart';
import '../common/overlays/page_sheet.dart';
import 'temperature_coverage_card.dart';

Future<void> showOutfitInsightsSheet(BuildContext context) {
  return pageSheet<void>(
    context,
    title: AppLocalizations.of(context).outfitInsights,
    builder: (_) => const OutfitInsightsSheetContent(),
  );
}

class OutfitInsightsSheetContent extends ConsumerStatefulWidget {
  const OutfitInsightsSheetContent({super.key});

  @override
  ConsumerState<OutfitInsightsSheetContent> createState() =>
      _OutfitInsightsSheetContentState();
}

class _OutfitInsightsSheetContentState
    extends ConsumerState<OutfitInsightsSheetContent> {
  /// 0 = Style, 1 = Temperature.
  int _tabIndex = 0;

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
      _watchAuthExpiry(temperatureCoverageProvider);
    });
  }

  /// `ErrorStateWidget` renders nothing for auth expiry, so without this the
  /// sheet would go blank instead of prompting to log in again.
  void _watchAuthExpiry<T>(ProviderListenable<AsyncValue<T>> provider) {
    ref.listenManual<AsyncValue<T>>(provider, (_, next) {
      if (isSettledAuthExpiry(next) && mounted) {
        AuthExpiredHandler.handle(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedSwitch(
            labels: [
              l10n.outfitInsightsStyleTab,
              l10n.outfitInsightsTemperatureTab,
            ],
            selectedIndex: _tabIndex,
            onSelected: (i) => setState(() => _tabIndex = i),
          ),
        ),
        const SizedBox(height: AppDimens.cardSpacing),
        // IndexedStack keeps each tab's scroll position across switches.
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            sizing: StackFit.expand,
            children: [_buildStyleTab(), _buildTemperatureTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildStyleTab() {
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
      data: (profile) => _buildTabList([
        _buildRadarCard(profile.preferences),
        const SizedBox(height: AppDimens.sectionSpacing),
        _buildStyleProfileCard(),
      ]),
    );

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (isInitialLoading)
          Positioned.fill(
            child: LoadingOverlay(label: l10n.loadingOutfitInsightsEllipsis),
          ),
      ],
    );
  }

  Widget _buildTemperatureTab() =>
      _buildTabList([_buildTemperatureCoverageCard()]);

  Widget _buildTabList(List<Widget> children) {
    return ListView(
      padding: EdgeInsets.only(
        top: 4,
        bottom: MediaQuery.paddingOf(context).bottom,
      ),
      children: children,
    );
  }

  /// Own fetch, like the style distribution card.
  Widget _buildTemperatureCoverageCard() {
    final coverageAsync = ref.watch(temperatureCoverageProvider);
    return TemperatureCoverageCard(
      coverage: coverageAsync.value,
      child: coverageAsync.hasError && !coverageAsync.isLoading
          ? ErrorStateWidget(
              error: coverageAsync.error!,
              onRetry: () => ref.invalidate(temperatureCoverageProvider),
            )
          : const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Center(child: AppSpinner()),
            ),
    );
  }

  Widget _buildRadarCard(List<StyleTastePreference> preferences) {
    final l10n = AppLocalizations.of(context);
    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      blurRadius: 16,
      title: l10n.styleTasteRadarCardTitle,
      actionIcon: preferences.isEmpty ? null : const InfoGlyph(),
      actionTooltip: l10n.moreInfo,
      onAction: () => _showStyleInsightsDialog(preferences),
      child: LayoutBuilder(
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
    );
  }

  void _showStyleInsightsDialog(List<StyleTastePreference> preferences) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => AppDialog(
        title: l10n.styleTasteDetailsLabel,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < preferences.length; i++) ...[
                if (i > 0) const AppDivider(topSpacing: 12, bottomSpacing: 12),
                _buildInsightRow(preferences[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Separate fetch, so a slow/failed request doesn't block the sheet.
  Widget _buildStyleProfileCard() {
    final l10n = AppLocalizations.of(context);
    final styleProfileAsync = ref.watch(styleProfileProvider);
    // An outfit can have several style tags, so the per-tag sum
    // over-counts; the center shows the real outfit total instead.
    final generalOutfitCount =
        ref
            .watch(outfitsProvider)
            .value
            ?.fold<int>(0, (sum, g) => sum + g.versionCount) ??
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

        final pie = StyleProfilePieChart(
          size: _pieSize,
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
        );
        final legend = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final slice in slices)
              _buildStyleProfileLegendRow(slice, total),
          ],
        );
        return _buildStyleProfileCardShell(
          LayoutBuilder(
            builder: (context, constraints) {
              final besidePie = constraints.maxWidth - _pieSize - _pieLegendGap;
              if (besidePie >= _legendWidthNeeded(context, slices)) {
                return Row(
                  children: [
                    pie,
                    const SizedBox(width: _pieLegendGap),
                    Expanded(child: legend),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: pie),
                  const SizedBox(height: AppDimens.cardSpacing),
                  legend,
                ],
              );
            },
          ),
        );
      },
    );
  }

  static const double _pieSize = 120;
  static const double _pieLegendGap = 20;

  /// The widest legend row on one line: dot, gaps, name and "100%".
  double _legendWidthNeeded(
    BuildContext context,
    List<StyleProfileSlice> slices,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final widestName = slices.fold<double>(
      0,
      (w, s) => math.max(w, measure(s.label, AppTextStyle.regular14)),
    );
    return 10 + 8 + widestName + 8 + measure('100%', AppTextStyle.bold14);
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
}
