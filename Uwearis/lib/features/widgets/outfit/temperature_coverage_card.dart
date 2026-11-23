import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/temperature_coverage.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/cards/app_card_shell.dart';

/// Daily-pick outfit counts per temperature band. Read-only.
class TemperatureCoverageCard extends StatelessWidget {
  /// Null while loading; [child] then replaces the band list.
  final TemperatureCoverage? coverage;
  final Widget? child;

  const TemperatureCoverageCard({
    super.key,
    required this.coverage,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coverage = this.coverage;
    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      blurRadius: 16,
      title: l10n.temperatureCoverageCardTitle,
      subtitle: l10n.temperatureCoverageCardSubtitle,
      child: coverage == null ? child : _buildBands(l10n, coverage),
    );
  }

  Widget _buildBands(AppLocalizations l10n, TemperatureCoverage coverage) {
    final maxCount = coverage.bands.fold<int>(
      0,
      (m, b) => b.outfitCount > m ? b.outfitCount : m,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final band in coverage.bands)
          _TemperatureBandRow(
            key: band.key == null ? null : ValueKey<String>(band.key!),
            band: band,
            range: bandRange(l10n, band),
            fraction: maxCount == 0 ? 0 : band.outfitCount / maxCount,
          ),
      ],
    );
  }

  /// "Below 0°C", "15–20°C", "29°C and above".
  static String bandRange(AppLocalizations l10n, TemperatureBand band) {
    final min = band.minC;
    final max = band.maxC;
    if (min == null && max != null) {
      return l10n.temperatureBandBelow(_formatDegrees(max));
    }
    if (max == null && min != null) {
      return l10n.temperatureBandAbove(_formatDegrees(min));
    }
    return l10n.temperatureBandRange(
      _formatDegrees(min ?? 0),
      _formatDegrees(max ?? 0),
    );
  }

  static String _formatDegrees(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

class _TemperatureBandRow extends StatelessWidget {
  final TemperatureBand band;
  final String range;
  final double fraction;

  const _TemperatureBandRow({
    super.key,
    required this.band,
    required this.range,
    required this.fraction,
  });

  static const double _barHeight = 4;

  @override
  Widget build(BuildContext context) {
    final name = band.label;
    return Semantics(
      label: '${name == null ? range : '$name $range'}, ${band.outfitCount}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: name == null
                      ? Text(range, style: AppTextStyle.medium14)
                      : Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(name, style: AppTextStyle.medium14),
                            Text(
                              range,
                              style: AppTextStyle.regular14.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${band.outfitCount}',
                  style: AppTextStyle.bold14.copyWith(
                    color: band.outfitCount == 0
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_barHeight / 2),
      child: SizedBox(
        height: _barHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.borderSubtle),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0, 1),
              child: const ColoredBox(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
