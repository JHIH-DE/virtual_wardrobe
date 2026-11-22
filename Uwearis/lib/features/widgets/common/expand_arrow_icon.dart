import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_durations.dart';

/// A collapsible section's chevron: the back button's `<` glyph rotated,
/// since Material has no up/down version of it.
class ExpandArrowIcon extends StatelessWidget {
  final bool expanded;
  final double size;

  const ExpandArrowIcon({super.key, required this.expanded, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.fast,
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
