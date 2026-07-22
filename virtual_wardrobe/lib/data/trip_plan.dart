import 'package:flutter/material.dart';

import 'location_result.dart';

/// One leg of a trip: a single location for a sub-range of the trip's dates.
/// A single-destination trip just has one leg.
class TripLeg {
  final LocationResult location;
  final DateTimeRange dateRange;

  const TripLeg({required this.location, required this.dateRange});

  TripLeg copyWith({LocationResult? location, DateTimeRange? dateRange}) {
    return TripLeg(
      location: location ?? this.location,
      dateRange: dateRange ?? this.dateRange,
    );
  }

  factory TripLeg.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    return TripLeg(
      location: LocationResult(
        name: json['location'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        timezone: json['timezone'] as String? ?? 'UTC',
      ),
      dateRange: DateTimeRange(
        start: parseDate(json['start_date']),
        end: parseDate(json['end_date']),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    String dateOnly(DateTime d) => d.toIso8601String().split('T')[0];
    return {
      'location': location.name,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timezone': location.timezone,
      'start_date': dateOnly(dateRange.start),
      'end_date': dateOnly(dateRange.end),
    };
  }
}

class TripPlan {
  final String id;
  final String name;
  final String purpose;
  final List<TripLeg> legs;

  TripPlan({
    required this.id,
    required this.name,
    required this.purpose,
    required this.legs,
  }) : assert(legs.isNotEmpty, 'A trip needs at least one leg');

  /// Overall trip span: earliest leg start to latest leg end.
  DateTimeRange get dateRange {
    var start = legs.first.dateRange.start;
    var end = legs.first.dateRange.end;
    for (final leg in legs.skip(1)) {
      if (leg.dateRange.start.isBefore(start)) start = leg.dateRange.start;
      if (leg.dateRange.end.isAfter(end)) end = leg.dateRange.end;
    }
    return DateTimeRange(start: start, end: end);
  }

  /// First leg's location, for call sites that only care about one place.
  LocationResult get location => legs.first.location;

  /// "Tokyo • Yokohama • Kamakura" (stripping country if present).
  String get locationSummary => legs
      .map((l) {
        final name = l.location.name;
        return name.contains(',') ? name.split(',').first.trim() : name;
      })
      .join(' • ');

  /// The leg active on [date], if any.
  TripLeg? legForDate(DateTime date) {
    for (final leg in legs) {
      final start = DateTime(
        leg.dateRange.start.year,
        leg.dateRange.start.month,
        leg.dateRange.start.day,
      );
      final end = DateTime(
        leg.dateRange.end.year,
        leg.dateRange.end.month,
        leg.dateRange.end.day,
      );
      final day = DateTime(date.year, date.month, date.day);
      if (!day.isBefore(start) && !day.isAfter(end)) return leg;
    }
    return null;
  }

  TripPlan copyWith({String? name, String? purpose, List<TripLeg>? legs}) {
    return TripPlan(
      id: id,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      legs: legs ?? this.legs,
    );
  }

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    final rawLegs = json['legs'];
    List<TripLeg> legs;
    if (rawLegs is List && rawLegs.isNotEmpty) {
      legs = rawLegs
          .whereType<Map<String, dynamic>>()
          .map(TripLeg.fromJson)
          .toList();
    } else {
      // Backward-compat with the old single-location trip shape.
      legs = [TripLeg.fromJson(json)];
    }

    return TripPlan(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      legs: legs,
    );
  }
}
