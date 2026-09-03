import 'package:flutter/widgets.dart';

import '../../../../data/outfit.dart';
import '../../../../data/style_type.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'filter_button.dart';

/// Season + style filter state shared by the Outfits tab and the
/// "used in outfits" list. Holds the two selected-value sets and applies
/// the filter — the page owns one instance and rebuilds on change.
class OutfitSeasonStyleFilter {
  static const List<String> _seasons = ['All', ...seasonOptions];
  static const List<String> _styles = ['All', ...styleOptions];

  Set<String> seasons = {'All'};
  Set<String> styles = {'All'};

  bool get isActive => !seasons.contains('All') || !styles.contains('All');

  // The backend's style tags are snake_case (`smart_casual`) while the
  // filter chips show Title Case with spaces ("Smart Casual") — normalize
  // both sides to compare regardless of separator/case.
  static String _normalizeStyle(String s) =>
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
            (s) => styles.any((sel) => _normalizeStyle(sel) == _normalizeStyle(s)),
          );
      return okSeason && okStyle;
    }).toList();
  }

  /// The standard season + style [FilterButton]. [onChanged] fires after a
  /// selection changes — call `setState` there.
  FilterButton buildButton(
    AppLocalizations l10n, {
    required VoidCallback onChanged,
  }) {
    return FilterButton(
      isFiltered: isActive,
      groups: [
        FilterGroup.toggleAll(
          label: l10n.seasonLabel,
          options: _seasons,
          selected: () => seasons,
          onChanged: (next) {
            seasons = next;
            onChanged();
          },
        ),
        FilterGroup.toggleAll(
          label: l10n.styleLabel,
          options: _styles,
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
