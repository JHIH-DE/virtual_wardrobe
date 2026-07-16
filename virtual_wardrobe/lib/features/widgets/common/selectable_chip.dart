import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Rounded pill: filled [selectedColor] when [selected], outlined otherwise.
/// Colors/text style default to the standard filter-chip look; pass overrides
/// (as `CategorySelector` does) for other pill styles, e.g. a tab selector.
class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color selectedColor;
  final Color unselectedFillColor;
  final Color unselectedBorderColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final TextStyle textStyle;
  final EdgeInsetsGeometry padding;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.selectedColor = AppColors.primary,
    this.unselectedFillColor = Colors.transparent,
    this.unselectedBorderColor = AppColors.borderSubtle,
    this.selectedTextColor = AppColors.textOnPrimary,
    this.unselectedTextColor = AppColors.textPrimary,
    this.textStyle = AppTextStyle.semibold14,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? selectedColor : unselectedFillColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : unselectedBorderColor,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: textStyle.copyWith(
            color: selected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}
