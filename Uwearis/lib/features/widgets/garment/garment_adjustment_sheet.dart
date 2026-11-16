import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/garment_adjustment.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/overlays/picker_sheet.dart';

/// One radio list per adjustment (the single-choice sheets' rows), in the
/// backend's option order behind a leading "Default". Unlike
/// [showSingleChoiceSheet] a pick doesn't close it — there may be several
/// adjustments.
///
/// Resolves once the sheet closes: the new explicit picks (keys left on
/// Default are absent), or null if nothing changed. Default is never sent as
/// its `default_code` — the backend's default depends on the rest of the
/// outfit.
///
/// [notes] puts a line under an adjustment's title, keyed by `key` — e.g.
/// one that only applies with long trousers.
Future<Map<String, int>?> showGarmentAdjustmentSheet(
  BuildContext context, {
  required List<AdjustmentDefinition> definitions,
  required Map<String, int> selected,
  Map<String, String> notes = const {},
}) async {
  final picks = {...selected};
  await showPickerSheet<void>(
    context,
    fitContent: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setSheetState) => _GarmentAdjustmentSheetBody(
        definitions: definitions,
        notes: notes,
        picks: picks,
        onPick: (key, code) => setSheetState(() {
          if (code == null) {
            picks.remove(key);
          } else {
            picks[key] = code;
          }
        }),
      ),
    ),
  );
  return mapEquals(picks, selected) ? null : picks;
}

/// An option code, or null for Default — a record so Default is a real
/// radio value, not "nothing selected".
typedef _Choice = ({int? code});

class _GarmentAdjustmentSheetBody extends StatelessWidget {
  static const double _groupSpacing = 24;

  final List<AdjustmentDefinition> definitions;
  final Map<String, String> notes;
  final Map<String, int> picks;
  final void Function(String key, int? code) onPick;

  const _GarmentAdjustmentSheetBody({
    required this.definitions,
    required this.notes,
    required this.picks,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetDragHandle(),
        const SizedBox(height: 20),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < definitions.length; i++) ...[
                if (i > 0) const SizedBox(height: _groupSpacing),
                _buildGroup(definitions[i], l10n),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroup(AdjustmentDefinition def, AppLocalizations l10n) {
    final labels = {for (final o in def.options) o.code: o.label};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PickerSheetHeader(
          def.label,
          description: notes[def.key],
          dragHandle: false,
        ),
        SingleChoiceList<_Choice>(
          options: [(code: null), for (final o in def.options) (code: o.code)],
          selected: (code: picks[def.key]),
          labelOf: (c) =>
              c.code == null ? l10n.adjustmentDefault : labels[c.code]!,
          onSelected: (c) => onPick(def.key, c.code),
        ),
      ],
    );
  }
}
