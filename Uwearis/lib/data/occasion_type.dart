import 'package:flutter/material.dart';

/// Stable identifiers for the occasion a user assigns to each day of their
/// weekly routine — this is what Uwearis reads to personalize outfit
/// recommendations. Persisted locally (SharedPreferences); the stored
/// values must stay stable even if the display label/icon changes.
enum OccasionType { work, casual, workout, date, travel, party }

extension OccasionTypeApi on OccasionType {
  String get apiValue => name;

  /// The occasion string sent to `POST /api/v1/outfit/advice` ("Complete
  /// with AI") — deliberately **not** [apiValue]. That backend endpoint
  /// only applies its formality pre-filter to a fixed vocabulary
  /// (`casual_daily` / `smart_casual` / `business` / `business_formal` /
  /// `interview` / `date_night` / `party` / `wedding_guest` / `outdoor` /
  /// `travel` / `sport` / `home_lounge` — see the Outfit Advice tech pack);
  /// anything else is accepted but silently skips the filter. [apiValue]
  /// stays a stable identifier used for local persistence (Lifestyle's
  /// weekly occasion routine, `lifestyle_page.dart`) and must never change
  /// shape to chase an unrelated backend's vocabulary.
  ///
  /// This app is casual-leaning, so `work` maps to `smart_casual` rather
  /// than `business`/`business_formal`/`interview` — those finer corporate
  /// dress-code tiers aren't a distinction this app's users make.
  String get outfitAdviceOccasion {
    switch (this) {
      case OccasionType.work:
        return 'smart_casual';
      case OccasionType.casual:
        return 'casual_daily';
      case OccasionType.workout:
        return 'sport';
      case OccasionType.date:
        return 'date_night';
      case OccasionType.travel:
        return 'travel';
      case OccasionType.party:
        return 'party';
    }
  }

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
