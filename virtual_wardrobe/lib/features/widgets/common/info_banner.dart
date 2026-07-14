import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Rounded, bordered banner with a leading icon and a content slot —
/// used for AI-suggestion / tip-style call-outs.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const InfoBanner({
    super.key,
    this.icon = Icons.auto_awesome,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.iconSize = 18,
    this.padding = const EdgeInsets.all(12),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? AppColors.dividerSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: iconSize, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
