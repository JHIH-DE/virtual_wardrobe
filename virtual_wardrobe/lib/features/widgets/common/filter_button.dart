import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
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
  final String? emptyMessage;

  FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.emptyMessage,
  });
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
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.overlaySubtle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < groups.length; i++) ...[
                  Text(groups[i].label, style: AppTextStyle.bold16),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.dividerSubtle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  groups[i].options.isEmpty
                      ? Text(
                          groups[i].emptyMessage ??
                              l10n.noOptionsAvailable(
                                groups[i].label.toLowerCase(),
                              ),
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: groups[i].options.map((opt) {
                            final selected = groups[i].selected().contains(opt);
                            return SelectableChip(
                              label: opt,
                              selected: selected,
                              selectedColor: AppColors.accentTint,
                              selectedTextColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _openFilterSheet(context),
        ),
        if (isFiltered)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
