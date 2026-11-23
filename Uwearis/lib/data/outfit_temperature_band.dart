import '../l10n/generated/app_localizations.dart';
import 'outfit.dart';

/// The backend's fixed temperature bands (`TEMPERATURE_BANDS`, the `key`s
/// of `GET /daily_outfits/temperature-coverage`), each `[minC, maxC)`; a
/// null end is open.
enum OutfitTemperatureBand {
  freezing('freezing', null, 0),
  cold('cold', 0, 10),
  chilly('chilly', 10, 15),
  cool('cool', 15, 20),
  mild('mild', 20, 25),
  warm('warm', 25, 29),
  hot('hot', 29, null);

  final String apiValue;
  final int? minC;
  final int? maxC;

  const OutfitTemperatureBand(this.apiValue, this.minC, this.maxC);

  static OutfitTemperatureBand? fromApiValue(String? value) {
    for (final b in values) {
      if (b.apiValue == value) return b;
    }
    return null;
  }

  /// Whether [outfit] suits some temperature in this band. An outfit with
  /// no range, or an empty one, suits none.
  bool includes(Outfit outfit) {
    final min = outfit.suitableTempMinC;
    final max = outfit.suitableTempMaxC;
    if (min == null && max == null) return false;
    if (min != null && max != null && min >= max) return false;
    final startsBeforeBandEnds = min == null || maxC == null || min < maxC!;
    final endsAfterBandStarts = max == null || minC == null || max > minC!;
    return startsBeforeBandEnds && endsAfterBandStarts;
  }

  String label(AppLocalizations l10n) => switch (this) {
    freezing => l10n.temperatureBandNameFreezing,
    cold => l10n.temperatureBandNameCold,
    chilly => l10n.temperatureBandNameChilly,
    cool => l10n.temperatureBandNameCool,
    mild => l10n.temperatureBandNameMild,
    warm => l10n.temperatureBandNameWarm,
    hot => l10n.temperatureBandNameHot,
  };
}
