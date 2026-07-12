import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';
import '../common/filter_icon_button.dart';
import '../common/filter_sheet_scaffold.dart';
import '../common/selectable_chip.dart';

/// Tune icon (with an active-filter dot) that opens a Color / Product Type
/// bottom sheet. Selection uses an 'All' sentinel: picking 'All' clears the
/// rest, picking anything else clears 'All'.
class GarmentFilterButton extends StatelessWidget {
  final bool isFiltered;
  final List<String> availableColors;
  final List<String> availableTypes;
  final Set<String> Function() selectedColors;
  final Set<String> Function() selectedTypes;
  final ValueChanged<Set<String>> onColorsChanged;
  final ValueChanged<Set<String>> onTypesChanged;

  const GarmentFilterButton({
    super.key,
    required this.isFiltered,
    required this.availableColors,
    required this.availableTypes,
    required this.selectedColors,
    required this.selectedTypes,
    required this.onColorsChanged,
    required this.onTypesChanged,
  });

  static Set<String> toggle(Set<String> current, String value) {
    if (value == 'All') return {'All'};
    final next = Set<String>.from(current)..remove('All');
    if (next.contains(value)) {
      next.remove(value);
      if (next.isEmpty) next.add('All');
    } else {
      next.add(value);
    }
    return next;
  }

  void _openFilterSheet(BuildContext context) {
    showAppFilterSheet(
      context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Widget chipRow(
            List<String> options,
            Set<String> selected,
            ValueChanged<Set<String>> onChanged,
          ) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((s) {
                return SelectableChip(
                  label: s,
                  selected: selected.contains(s),
                  onTap: () {
                    onChanged(toggle(selected, s));
                    setSheetState(() {});
                  },
                );
              }).toList(),
            );
          }

          return FilterSheetContent(
            children: [
              Text('Color', style: AppTextStyle.bold16),
              const SizedBox(height: 10),
              chipRow(availableColors, selectedColors(), onColorsChanged),
              const SizedBox(height: 20),
              Text('Product Type', style: AppTextStyle.bold16),
              const SizedBox(height: 10),
              chipRow(availableTypes, selectedTypes(), onTypesChanged),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilterIconButton(
      isFiltered: isFiltered,
      onPressed: () => _openFilterSheet(context),
    );
  }
}
