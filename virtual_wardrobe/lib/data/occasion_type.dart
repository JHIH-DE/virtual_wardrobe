import 'package:flutter/material.dart';

/// Stable identifiers for the occasion a user assigns to each day of their
/// weekly routine — this is what Uwearis reads to personalize outfit
/// recommendations. Persisted locally (SharedPreferences); the stored
/// values must stay stable even if the display label/icon changes.
enum OccasionType { work, casual, workout, date, travel, party }

extension OccasionTypeApi on OccasionType {
  String get apiValue => name;

  IconData get icon {
    switch (this) {
      case OccasionType.work:
        return Icons.work_outline;
      case OccasionType.casual:
        return Icons.home_outlined;
      case OccasionType.workout:
        return Icons.fitness_center_outlined;
      case OccasionType.date:
        return Icons.favorite_border;
      case OccasionType.travel:
        return Icons.flight_outlined;
      case OccasionType.party:
        return Icons.wine_bar_outlined;
    }
  }
}

OccasionType? occasionTypeFromApiValue(String value) {
  for (final occasion in OccasionType.values) {
    if (occasion.apiValue == value) return occasion;
  }
  return null;
}
