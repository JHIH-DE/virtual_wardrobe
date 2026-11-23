import 'package:flutter/widgets.dart';

import '../../../../core/providers/outfits_provider.dart';
import '../../../../data/outfit.dart';
import '../../../../data/outfit_group.dart';
import '../../../../data/outfit_temperature_band.dart';
import '../../../../data/style_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../outfit/outfit_title.dart';
import 'filter_button.dart';

/// Temperature-band + style filter state for the Outfits tab and a
/// garment's outfit list. The page owns one instance and rebuilds on change.
class OutfitTemperatureStyleFilter {
  static const String all = 'All';

  /// [OutfitTemperatureBand.apiValue]s, or [all].
  Set<String> temperatures = {all};
  Set<String> styles = {all};

  bool get isActive => !temperatures.contains(all) || !styles.contains(all);

  List<OutfitTemperatureBand> get _selectedBands => [
    for (final b in OutfitTemperatureBand.values)
      if (temperatures.contains(b.apiValue)) b,
  ];

  /// Whether one version passes both groups.
  bool matches(Outfit outfit) {
    final okTemperature =
        temperatures.contains(all) ||
        _selectedBands.any((b) => b.includes(outfit));
    final okStyle =
        styles.contains(all) ||
        outfit.style.any((t) => styles.contains(normalizeOutfitTag(t)));
    return okTemperature && okStyle;
  }

  /// [matches] while a filter is set; null shows everything.
  bool Function(Outfit)? get versionFilter => isActive ? matches : null;

  List<Outfit> apply(List<Outfit> outfits) => outfits.where(matches).toList();

  /// One card per group with a matching version: its cover when that
  /// matches, else its first matching version.
  List<Outfit> applyToGroups(List<OutfitGroup> groups) {
    if (!isActive) return outfitGroupCovers(groups);
    return [for (final g in groups) ?_cardFor(g)];
  }

  Outfit? _cardFor(OutfitGroup group) {
    final cover = group.cover;
    if (cover != null && matches(cover)) return cover;
    for (final v in group.versions) {
      if (matches(v)) return v;
    }
    return null;
  }

  /// Bands at least one of [outfits] suits, coldest first. Selected bands
  /// are always kept so an active filter can't become an invisible chip.
  List<OutfitTemperatureBand> visibleTemperatureOptions(List<Outfit> outfits) =>
      [
        for (final b in OutfitTemperatureBand.values)
          if (temperatures.contains(b.apiValue) || outfits.any(b.includes)) b,
      ];

  /// [styleOptions] narrowed to tags used by [outfits], plus selected ones.
  List<String> visibleStyleOptions(List<Outfit> outfits) {
    final inUse = outfits
        .expand((o) => o.style)
        .map(normalizeOutfitTag)
        .toSet();
    return styleOptions
        .where((v) => inUse.contains(v) || styles.contains(v))
        .toList();
  }

  /// Call `setState` in [onChanged].
  FilterButton buildButton(
    AppLocalizations l10n,
    List<Outfit> outfits, {
    required VoidCallback onChanged,
  }) {
    final bands = visibleTemperatureOptions(outfits);
    final styleOpts = visibleStyleOptions(outfits);
    return FilterButton(
      isFiltered: isActive,
      groups: [
        FilterGroup.toggleAll(
          label: l10n.temperatureFieldLabel,
          options: bands.isEmpty
              ? const []
              : [all, for (final b in bands) b.apiValue],
          labelOf: (v) =>
              OutfitTemperatureBand.fromApiValue(v)?.label(l10n) ?? v,
          selected: () => temperatures,
          onChanged: (next) {
            temperatures = next;
            onChanged();
          },
        ),
        FilterGroup.toggleAll(
          label: l10n.styleLabel,
          options: styleOpts.isEmpty ? const [] : [all, ...styleOpts],
          labelOf: (v) => outfitTagLabel(l10n, v),
          selected: () => styles,
          onChanged: (next) {
            styles = next;
            onChanged();
          },
        ),
      ],
    );
  }
}
