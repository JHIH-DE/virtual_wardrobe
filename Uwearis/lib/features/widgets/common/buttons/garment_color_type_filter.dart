import 'package:flutter/widgets.dart';

import '../../../../data/garment.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'filter_button.dart';

/// Colour + product-type filter state for a garment grid; the page owns one
/// instance and rebuilds on change.
///
/// My Closet deliberately keeps its own: it orders colours by the
/// `GarmentColor` enum and pre-filters by category.
class GarmentColorTypeFilter {
  Set<String> colors = {'All'};
  Set<String> types = {'All'};

  bool get isActive => !colors.contains('All') || !types.contains('All');

  List<String> availableColors(List<Garment> pool) {
    final values =
        pool
            .map((g) => g.color)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  List<String> availableTypes(List<Garment> pool) {
    final values =
        pool
            .map((g) => g.subCategory)
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  List<Garment> apply(List<Garment> pool) {
    return pool.where((g) {
      final okColor =
          colors.contains('All') ||
          (g.color != null &&
              colors.any((c) => c.toLowerCase() == g.color!.toLowerCase()));
      final okType =
          types.contains('All') ||
          types.any((t) => t.toLowerCase() == g.subCategory.toLowerCase());
      return okColor && okType;
    }).toList();
  }

  void reset() {
    colors = {'All'};
    types = {'All'};
  }

  /// The standard colour + product-type [FilterButton]. [onChanged] fires
  /// after a selection changes — call `setState` there.
  FilterButton buildButton(
    AppLocalizations l10n,
    List<Garment> pool, {
    required VoidCallback onChanged,
  }) {
    return FilterButton(
      isFiltered: isActive,
      groups: [
        FilterGroup.toggleAll(
          label: l10n.color,
          options: availableColors(pool),
          selected: () => colors,
          onChanged: (next) {
            colors = next;
            onChanged();
          },
        ),
        FilterGroup.toggleAll(
          label: l10n.productType,
          options: availableTypes(pool),
          selected: () => types,
          onChanged: (next) {
            types = next;
            onChanged();
          },
        ),
      ],
    );
  }
}
