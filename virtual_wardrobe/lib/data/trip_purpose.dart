/// Stable trip-purpose identifiers, matching the snake_case values already
/// stored in `TripPlan.purpose` and sent to the API — introducing this enum
/// doesn't change the wire format, only how the picker UI represents it.
enum TripPurpose {
  leisureTravel,
  businessTrip,
  familyTrip,
  outdoorTrip,
  cityTrip,
  resortVacation,
  mixed,
}

extension TripPurposeApi on TripPurpose {
  String get apiValue {
    switch (this) {
      case TripPurpose.leisureTravel:
        return 'leisure_travel';
      case TripPurpose.businessTrip:
        return 'business_trip';
      case TripPurpose.familyTrip:
        return 'family_trip';
      case TripPurpose.outdoorTrip:
        return 'outdoor_trip';
      case TripPurpose.cityTrip:
        return 'city_trip';
      case TripPurpose.resortVacation:
        return 'resort_vacation';
      case TripPurpose.mixed:
        return 'mixed';
    }
  }
}

TripPurpose? tripPurposeFromApiValue(String value) {
  for (final purpose in TripPurpose.values) {
    if (purpose.apiValue == value) return purpose;
  }
  return null;
}
