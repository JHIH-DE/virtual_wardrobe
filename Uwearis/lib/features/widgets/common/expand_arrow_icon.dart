import 'package:flutter/material.dart';

/// The chevron next to a collapsible section's title (trip's outfit advice,
/// Accessories & Background, Style Taste details, per-category advice) —
/// swaps between the up/down asset rather than rotating a single glyph, so
/// every one of these sections shows the same pair of arrows.
class ExpandArrowIcon extends StatelessWidget {
  final bool expanded;
  final double size;

  const ExpandArrowIcon({super.key, required this.expanded, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Image.asset(
        expanded
            ? 'assets/images/page_arrow_up.png'
            : 'assets/images/page_arrow_down.png',
        key: ValueKey(expanded),
        width: size,
        height: size,
      ),
    );
  }
}
