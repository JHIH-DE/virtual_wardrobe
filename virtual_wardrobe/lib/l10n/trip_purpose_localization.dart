import 'package:flutter/widgets.dart';

import '../data/trip_purpose.dart';
import 'generated/app_localizations.dart';

extension TripPurposeLocalization on TripPurpose {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case TripPurpose.leisureTravel:
        return l10n.tripPurposeLeisureTravel;
      case TripPurpose.businessTrip:
        return l10n.tripPurposeBusinessTrip;
      case TripPurpose.familyTrip:
        return l10n.tripPurposeFamilyTrip;
      case TripPurpose.outdoorTrip:
        return l10n.tripPurposeOutdoorTrip;
      case TripPurpose.cityTrip:
        return l10n.tripPurposeCityTrip;
      case TripPurpose.resortVacation:
        return l10n.tripPurposeResortVacation;
      case TripPurpose.mixed:
        return l10n.tripPurposeMixed;
    }
  }
}
