import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared box-shadow recipes for card-style surfaces (see `TripPlanCard`).
abstract class AppShadows {
  /// Two-tone hard shadow that gives cards a slight "sticker" edge.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.cardShadowTop,
      offset: Offset(0, 2),
      blurRadius: 0,
    ),
    BoxShadow(
      color: AppColors.cardShadowBottom,
      offset: Offset(0, 4),
      blurRadius: 0,
    ),
  ];

  /// Soft diffuse drop shadow layered under [card] for extra depth.
  static BoxShadow get softDrop => BoxShadow(
    color: Colors.black.withValues(alpha: 0.18),
    offset: const Offset(0, 10),
    blurRadius: 20,
  );
}
