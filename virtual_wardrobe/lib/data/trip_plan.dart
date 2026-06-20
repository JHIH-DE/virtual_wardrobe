import 'package:flutter/material.dart';

class TripPlan {
  final String id;
  final String name;
  final DateTimeRange dateRange;
  final LocationResult location;
  final String style;

  TripPlan({
    required this.id,
    required this.name,
    required this.dateRange,
    required this.location,
    required this.style,
  });
}

class LocationResult {
  final String name;
  final double latitude;
  final double longitude;

  LocationResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
