import 'package:flutter/widgets.dart';

import '../../../../data/outfit.dart';
import '../../../../data/style_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'filter_button.dart';

/// Season + style filter state shared by the Outfits tab and the
/// "used in outfits" list. Holds the two selected-value sets and applies
/// the filter — the page owns one instance and rebuilds on change.
class OutfitSeasonStyleFilter {
  Set<String> seasons = {'All'};
  Set<String> styles = {'All'};

  bool get isActive => !seasons.contains('All') || !styles.contains('All');

  // The backend's style tags are snake_case (`smart_casual`) while the
  // filter chips show Title Case with spaces ("Smart Casual") — normalize
  // both sides to compare regardless of separator/case. Harmless for
  // seasons too (single words, no separators).
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

  /// The canonical [seasonOptions] narrowed to what's actually tagged on
  /// [outfits] — no point offering "Spring" as a filter when nothing is
  /// tagged Spring. A currently-selected value is always kept even if it's
  /// no longer present (e.g. its last outfit was just deleted), so an
  /// active filter never leaves an un-clearable invisible chip. Order
  /// follows [seasonOptions].
  List<String> visibleSeasonOptions(List<Outfit> outfits) =>
      _present(seasonOptions, outfits.expand((o) => o.seasons), seasons);

  /// [styleOptions] narrowed the same way [visibleSeasonOptions] narrows
  /// seasons.
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

  /// The standard season + style [FilterButton], with each group's chips
  /// limited to the tags present in [outfits] (see [visibleSeasonOptions] /
  /// [visibleStyleOptions]). [onChanged] fires after a selection changes —
  /// call `setState` there.
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
