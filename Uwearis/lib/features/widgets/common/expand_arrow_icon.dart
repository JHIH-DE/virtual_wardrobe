import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// The chevron next to a collapsible section's title (trip's outfit advice,
/// Accessories & Background, Style Taste details, per-category advice) —
/// the back button's `<` glyph turned to point up or down, so every one of
/// these sections shows the same pair of arrows. Material has no up/down
/// version of that glyph, hence the rotation.
class ExpandArrowIcon extends StatelessWidget {
  final bool expanded;
  final double size;

  const ExpandArrowIcon({super.key, required this.expanded, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: RotatedBox(
        key: ValueKey(expanded),
        quarterTurns: expanded ? 1 : 3,
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: size,
          color: AppColors.icon,
        ),
      ),
    );
  }
}
