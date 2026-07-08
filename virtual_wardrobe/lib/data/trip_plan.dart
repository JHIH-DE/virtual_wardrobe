import 'package:flutter/material.dart';

class TripPlan {
  final String id;
  final String name;
  final DateTimeRange dateRange;
  final LocationResult location;
  final String purpose;

  TripPlan({
    required this.id,
    required this.name,
    required this.dateRange,
    required this.location,
    required this.purpose,
  });

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    return TripPlan(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      dateRange: DateTimeRange(
        start: parseDate(json['start_date']),
        end: parseDate(json['end_date']),
      ),
      location: LocationResult(
        name: json['location'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        timezone: json['timezone'] as String? ?? 'UTC',
      ),
      purpose: json['purpose'] as String? ?? '',
    );
  }
}

class LocationResult {
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;

  LocationResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });
}
