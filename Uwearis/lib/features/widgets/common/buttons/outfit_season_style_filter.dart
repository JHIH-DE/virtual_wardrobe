import 'package:flutter/widgets.dart';

import '../../../../data/outfit.dart';
import '../../../../data/style_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'filter_button.dart';

/// Season + style filter state for the Outfits tab and a garment's outfit
/// list. The page owns one instance and rebuilds on change.
class OutfitSeasonStyleFilter {
  Set<String> seasons = {'All'};
  Set<String> styles = {'All'};

  bool get isActive => !seasons.contains('All') || !styles.contains('All');

  // Backend tags are snake_case (`smart_casual`), chips are "Smart Casual".
  static String _normalizeTag(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');

  List<Outfit> apply(List<Outfit> all) {
    return all.where((o) {
      final okSeason =
          seasons.contains('All') ||
          o.seasons.any(
            (s) => seasons.any((sel) => sel.toLowerCase() == s.toLowerCase()),
          );
      final okStyle =
          styles.contains('All') ||
          o.style.any(
            (s) => styles.any((sel) => _normalizeTag(sel) == _normalizeTag(s)),
          );
      return okSeason && okStyle;
    }).toList();
  }

  /// [seasonOptions] narrowed to tags used by [outfits]. Selected values are
  /// always kept so an active filter can't become an invisible chip.
  List<String> visibleSeasonOptions(List<Outfit> outfits) =>
      _present(seasonOptions, outfits.expand((o) => o.seasons), seasons);

  /// Same as [visibleSeasonOptions], for [styleOptions].
  List<String> visibleStyleOptions(List<Outfit> outfits) =>
      _present(styleOptions, outfits.expand((o) => o.style), styles);

  static List<String> _present(
    List<String> vocab,
    Iterable<String> tagsInUse,
    Set<String> selected,
  ) {
    final inUse = tagsInUse.map(_normalizeTag).toSet();
    return vocab
        .where((v) => inUse.contains(_normalizeTag(v)) || selected.contains(v))
        .toList();
  }

  /// Call `setState` in [onChanged].
  FilterButton buildButton(
    AppLocalizations l10n,
    List<Outfit> outfits, {
    required VoidCallback onChanged,
  }) {
    final seasonOpts = visibleSeasonOptions(outfits);
    final styleOpts = visibleStyleOptions(outfits);
    return FilterButton(
      isFiltered: isActive,
      groups: [
        FilterGroup.toggleAll(
          label: l10n.seasonLabel,
          options: seasonOpts.isEmpty ? const [] : ['All', ...seasonOpts],
          selected: () => seasons,
          onChanged: (next) {
            seasons = next;
            onChanged();
          },
        ),
        FilterGroup.toggleAll(
          label: l10n.styleLabel,
          options: styleOpts.isEmpty ? const [] : ['All', ...styleOpts],
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
