import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'filter_icon_button.dart';
import 'filter_sheet_scaffold.dart';
import 'selectable_chip.dart';

/// One labeled row of selectable chips inside a [FilterButton]'s sheet.
/// The group owns its own selection state and toggle logic, so callers
/// with different selection semantics (e.g. an 'All' sentinel vs plain
/// multi-select) can reuse the same sheet chrome.
class FilterGroup {
  final String label;
  final List<String> options;
  final Set<String> Function() selected;
  final void Function(String option) onToggle;
  final String emptyMessage;

  FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    String? emptyMessage,
  }) : emptyMessage = emptyMessage ?? 'No ${label.toLowerCase()} available';
}

/// Filter icon button that opens a bottom sheet built from [groups].
class FilterButton extends StatelessWidget {
  final bool isFiltered;
  final List<FilterGroup> groups;

  const FilterButton({
    super.key,
    required this.isFiltered,
    required this.groups,
  });

  /// Toggle helper for the common 'All' sentinel pattern: selecting 'All'
  /// clears the rest, selecting anything else clears 'All', and clearing
  /// the last non-'All' selection falls back to 'All'.
  static Set<String> toggleWithAll(Set<String> current, String value) {
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
          return FilterSheetContent(
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                Text(groups[i].label, style: AppTextStyle.bold16),
                const SizedBox(height: 10),
                groups[i].options.isEmpty
                    ? Text(
                        groups[i].emptyMessage,
                        style: AppTextStyle.regular14.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groups[i].options.map((opt) {
                          final selected = groups[i].selected().contains(opt);
                          return SelectableChip(
                            label: opt,
                            selected: selected,
                            onTap: () {
                              groups[i].onToggle(opt);
                              setSheetState(() {});
                            },
                          );
                        }).toList(),
                      ),
                if (i != groups.length - 1) const SizedBox(height: 20),
              ],
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
