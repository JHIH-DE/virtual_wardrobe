import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/outfit.dart';
import '../../../data/style_type.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/filter_button.dart';
import 'outfit_temperature_editor.dart';
import 'outfit_title.dart';

/// What the tags sheet changed: the full style list, and the suitable
/// temperature edit (null = unchanged).
typedef OutfitTagEdits = ({
  List<String> style,
  OutfitTemperatureEdit? temperature,
});

/// The suitable temperature and a Style multi-select (the filter sheets'
/// chip chrome, no "All") for [outfit]. Resolves once the sheet closes,
/// however it's dismissed: the edits, or null if nothing changed.
Future<OutfitTagEdits?> showOutfitTagsSheet(
  BuildContext context,
  Outfit outfit,
) async {
  final l10n = AppLocalizations.of(context);
  final initialStyles = outfit.style.map(normalizeOutfitTag).toSet();
  final selectedStyles = {...initialStyles};
  OutfitTemperatureEdit? temperature;

  await showChipGroupsSheet(
    context,
    leading: [
      OutfitTemperatureEditor(
        initial: outfit.suitableTemperature,
        onChanged: (edit) => temperature = edit,
      ),
    ],
    groups: [
      FilterGroup(
        label: l10n.styleLabel,
        options: styleOptions,
        labelOf: (v) => outfitTagLabel(l10n, v),
        selected: () => selectedStyles,
        onToggle: (option) {
          if (!selectedStyles.remove(option)) selectedStyles.add(option);
        },
      ),
    ],
  );
  final styleChanged = !setEquals(selectedStyles, initialStyles);
  if (!styleChanged && temperature == null) return null;
  return (
    style: styleChanged ? selectedStyles.toList() : outfit.style,
    temperature: temperature,
  );
}
