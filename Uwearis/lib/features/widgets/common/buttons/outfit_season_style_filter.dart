import 'package:flutter/widgets.dart';

import '../../../../data/outfit.dart';
import '../../../../data/style_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../outfit/outfit_title.dart';
import 'filter_button.dart';

/// Season + style filter state for the Outfits tab and a garment's outfit
/// list. The page owns one instance and rebuilds on change.
class OutfitSeasonStyleFilter {
  Set<String> seasons = {'All'};
  Set<String> styles = {'All'};

  bool get isActive => !seasons.contains('All') || !styles.contains('All');

  static bool _anyMatch(Iterable<String> tags, Set<String> selected) =>
      tags.any((t) => selected.contains(normalizeOutfitTag(t)));

  List<Outfit> apply(List<Outfit> all) {
    return all.where((o) {
      final okSeason = seasons.contains('All') || _anyMatch(o.seasons, seasons);
      final okStyle = styles.contains('All') || _anyMatch(o.style, styles);
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
    final inUse = tagsInUse.map(normalizeOutfitTag).toSet();
    return vocab
        .where((v) => inUse.contains(v) || selected.contains(v))
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
          labelOf: (v) => outfitTagLabel(l10n, v),
          selected: () => seasons,
          onChanged: (next) {
            seasons = next;
            onChanged();
          },
        ),
        FilterGroup.toggleAll(
          label: l10n.styleLabel,
          options: styleOpts.isEmpty ? const [] : ['All', ...styleOpts],
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
