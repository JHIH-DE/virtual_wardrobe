import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// White rounded pill with a shadow, label and icon. Matches the large
/// bottom-toolbar action look (fixed height, bordered, spaced-apart
/// label/icon — e.g. Retake / Album).
class PillButton extends StatelessWidget {
  final Widget label;
  final Widget icon;
  final VoidCallback onPressed;
  final double? height;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment mainAxisAlignment;
  final double gap;
  final BoxBorder? border;
  final List<BoxShadow> boxShadow;
  final Color color;

  const PillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 64,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.gap = 0,
    this.border = const Border.fromBorderSide(
      BorderSide(color: AppColors.borderSubtle),
    ),
    this.boxShadow = const [
      BoxShadow(
        color: AppColors.shadowResting,
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ],
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: border,
          boxShadow: boxShadow,
        ),
        child: Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [
            label,
            if (gap > 0) SizedBox(width: gap),
            icon,
          ],
        ),
      ),
    );
  }
}
