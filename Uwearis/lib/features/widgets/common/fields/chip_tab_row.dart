import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import 'selectable_chip.dart';

/// A horizontally scrolling row of pill tabs, one selected — the closet's
/// category tabs (`CategorySelector`) and the background picker's.
class ChipTabRow<T> extends StatelessWidget {
  final List<T> tabs;
  final T selected;
  final String Function(T tab) labelOf;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  const ChipTabRow({
    super.key,
    required this.tabs,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      scrollDirection: Axis.horizontal,
      itemCount: tabs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final tab = tabs[i];
        return SelectableChip(
          label: labelOf(tab),
          selected: tab == selected,
          onTap: () => onSelected(tab),
          selectedColor: AppColors.primary,
          unselectedFillColor: AppColors.surface,
          unselectedBorderColor: AppColors.borderSubtle,
          unselectedTextColor: AppColors.textPrimary,
          textStyle: AppTextStyle.bold16,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        );
      },
    );
  }
}
