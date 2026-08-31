import 'package:flutter/widgets.dart';

import '../data/trip.dart';
import 'generated/app_localizations.dart';

extension TripActivityLocalization on TripActivity {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case TripActivity.outdoor:
        return l10n.tripActivityOutdoor;
      case TripActivity.business:
        return l10n.tripActivityBusiness;
      case TripActivity.formalOccasion:
        return l10n.tripActivityFormalOccasion;
      case TripActivity.waterActivities:
        return l10n.tripActivityWaterActivities;
    }
  }
}
