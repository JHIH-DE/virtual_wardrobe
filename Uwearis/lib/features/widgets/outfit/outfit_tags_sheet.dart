import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/outfit.dart';
import '../../../data/style_type.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/filter_button.dart';
import 'outfit_title.dart';

/// An outfit's tags in the backend's form (lowercase seasons, snake_case
/// styles).
typedef OutfitTags = ({List<String> seasons, List<String> style});

/// Season/Style multi-select for [outfit] — the filter sheets' chip chrome,
/// plain multi-select (no "All"). Resolves once the sheet closes, however
/// it's dismissed: the new tags, or null if nothing changed.
Future<OutfitTags?> showOutfitTagsSheet(
  BuildContext context,
  Outfit outfit,
) async {
  final l10n = AppLocalizations.of(context);
  final initialSeasons = outfit.seasons.map(outfitTagLabel).toSet();
  final initialStyles = outfit.style.map(outfitTagLabel).toSet();
  final selectedSeasons = {...initialSeasons};
  final selectedStyles = {...initialStyles};

  FilterGroup tagGroup(String label, List<String> options, Set<String> sel) {
    return FilterGroup(
      label: label,
      options: options,
      selected: () => sel,
      onToggle: (option) {
        if (!sel.remove(option)) sel.add(option);
      },
    );
  }

  await showChipGroupsSheet(
    context,
    groups: [
      tagGroup(l10n.seasonLabel, seasonOptions, selectedSeasons),
      tagGroup(l10n.styleLabel, styleOptions, selectedStyles),
    ],
  );
  if (setEquals(selectedSeasons, initialSeasons) &&
      setEquals(selectedStyles, initialStyles)) {
    return null;
  }
  return (
    seasons: selectedSeasons.map((s) => s.toLowerCase()).toList(),
    // Back to the backend's snake_case.
    style: selectedStyles
        .map((s) => s.toLowerCase().replaceAll(' ', '_'))
        .toList(),
  );
}
