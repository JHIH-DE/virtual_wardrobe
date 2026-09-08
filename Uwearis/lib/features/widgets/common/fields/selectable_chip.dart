import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Rounded pill: filled [selectedColor] when [selected], outlined otherwise.
/// Colors/text style default to the standard filter-chip look; pass overrides
/// (as `CategorySelector` does) for other pill styles, e.g. a tab selector.
///
/// The visible pill stays as small as its [padding] + [textStyle] make it,
/// but the tap target is padded out (transparently) to
/// [AppDimens.minTouchTarget] tall so a near-miss above/below the pill still
/// registers. In a layout that hands the chip a tight height smaller than
/// that (a short horizontal strip), give the strip enough room — see
/// [CategorySelector].
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
    final pill = Container(
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
    );

    return GestureDetector(
      // opaque so the transparent band the ConstrainedBox adds above/below
      // the visible pill is still part of the tap target.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimens.minTouchTarget,
        ),
        // widthFactor keeps the row/Wrap seeing the pill's real width (so
        // chip spacing is unchanged); the Center only grows vertically to
        // fill the min-height band.
        child: Center(widthFactor: 1, child: pill),
      ),
    );
  }
}
