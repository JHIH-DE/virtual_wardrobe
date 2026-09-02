import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';

void main() {
  group('TripLeg', () {
    test('fromJson parses location and dates', () {
      final leg = TripLeg.fromJson({
        'location': 'Tokyo, Japan',
        'latitude': 35.68,
        'longitude': 139.69,
        'timezone': 'Asia/Tokyo',
        'start_date': '2026-10-01',
        'end_date': '2026-10-05',
      });

      expect(leg.location.name, 'Tokyo, Japan');
      expect(leg.location.latitude, 35.68);
      expect(leg.location.longitude, 139.69);
      expect(leg.location.timezone, 'Asia/Tokyo');
      expect(leg.dateRange.start, DateTime.parse('2026-10-01'));
      expect(leg.dateRange.end, DateTime.parse('2026-10-05'));
    });

    test('fromJson defaults missing fields rather than throwing', () {
      final leg = TripLeg.fromJson({});
      expect(leg.location.name, '');
      expect(leg.location.latitude, 0);
      expect(leg.location.longitude, 0);
      expect(leg.location.timezone, 'UTC');
      // An unparseable/missing date falls back to "now" rather than null,
      // since TripLeg.dateRange is non-nullable.
      expect(leg.dateRange.start, isNotNull);
    });

    test('toJson serializes dates as date-only (no time component)', () {
      final leg = TripLeg(
        location: LocationResult(
          name: 'Kyoto',
          latitude: 35.0,
          longitude: 135.77,
          timezone: 'Asia/Tokyo',
        ),
        dateRange: DateTimeRange(
          start: DateTime(2026, 10, 1, 13, 45),
          end: DateTime(2026, 10, 5, 9, 0),
        ),
      );

      final json = leg.toJson();
      expect(json['start_date'], '2026-10-01');
      expect(json['end_date'], '2026-10-05');
      expect(json['location'], 'Kyoto');
    });
  });

  group('Trip.fromJson', () {
    test('parses the multi-leg shape', () {
      final trip = Trip.fromJson({
        'id': 9,
        'name': 'Japan Trip',
        'activity': ['outdoor', 'business'],
        'legs': [
          {
            'location': 'Tokyo',
            'latitude': 35.68,
            'longitude': 139.69,
            'timezone': 'Asia/Tokyo',
            'start_date': '2026-10-01',
            'end_date': '2026-10-03',
          },
          {
            'location': 'Kyoto',
            'latitude': 35.0,
            'longitude': 135.77,
            'timezone': 'Asia/Tokyo',
            'start_date': '2026-10-04',
            'end_date': '2026-10-06',
          },
        ],
      });

      // Numeric ids come back as strings — every other id in the app is an
      // int, but Trip.id is used as a stable widget/route key.
      expect(trip.id, '9');
      expect(trip.name, 'Japan Trip');
      expect(trip.activities, ['outdoor', 'business']);
      expect(trip.legs, hasLength(2));
      expect(trip.legs[0].location.name, 'Tokyo');
      expect(trip.legs[1].location.name, 'Kyoto');
    });

    test('falls back to a single leg for the old single-location shape', () {
      final trip = Trip.fromJson({
        'id': 5,
        'name': 'Weekend Trip',
        'location': 'Osaka',
        'latitude': 34.69,
        'longitude': 135.5,
        'timezone': 'Asia/Tokyo',
        'start_date': '2026-11-01',
        'end_date': '2026-11-02',
      });

      expect(trip.legs, hasLength(1));
      expect(trip.legs.single.location.name, 'Osaka');
    });

    test('defaults activities to an empty list when missing', () {
      final trip = Trip.fromJson({
        'id': 1,
        'name': 'No Activities',
        'legs': [
          {
            'location': 'Taipei',
            'latitude': 25.03,
            'longitude': 121.56,
            'timezone': 'Asia/Taipei',
            'start_date': '2026-12-01',
            'end_date': '2026-12-02',
          },
        ],
      });
      expect(trip.activities, isEmpty);
    });
  });

  group('Trip computed properties', () {
    Trip buildTwoLegTrip() => Trip.fromJson({
      'id': 1,
      'name': 'Two Leg Trip',
      'legs': [
        {
          'location': 'Tokyo',
          'latitude': 35.68,
          'longitude': 139.69,
          'timezone': 'Asia/Tokyo',
          'start_date': '2026-10-01',
          'end_date': '2026-10-03',
        },
        {
          'location': 'Kyoto, Japan',
          'latitude': 35.0,
          'longitude': 135.77,
          'timezone': 'Asia/Tokyo',
          'start_date': '2026-10-05',
          'end_date': '2026-10-07',
        },
      ],
    });

    test('dateRange spans the earliest start to the latest end', () {
      final trip = buildTwoLegTrip();
      expect(trip.dateRange.start, DateTime.parse('2026-10-01'));
      expect(trip.dateRange.end, DateTime.parse('2026-10-07'));
    });

    test('location returns the first leg\'s location', () {
      final trip = buildTwoLegTrip();
      expect(trip.location.name, 'Tokyo');
    });

    test('locationSummary joins leg names and strips a trailing country', () {
      final trip = buildTwoLegTrip();
      expect(trip.locationSummary, 'Tokyo • Kyoto');
    });

    test('coveredDates excludes the gap day between legs', () {
      final trip = buildTwoLegTrip();
      // Span is Oct 1–7 (7 days), but Oct 4 belongs to neither leg.
      expect(trip.coveredDates, hasLength(6));
      expect(
        trip.coveredDates.any((d) => d.day == 4 && d.month == 10),
        isFalse,
      );
    });

    test('legForDate returns the leg covering that date, or null outside any leg', () {
      final trip = buildTwoLegTrip();
      expect(trip.legForDate(DateTime(2026, 10, 2))?.location.name, 'Tokyo');
      expect(
        trip.legForDate(DateTime(2026, 10, 6))?.location.name,
        'Kyoto, Japan',
      );
      expect(trip.legForDate(DateTime(2026, 10, 4)), isNull);
      expect(trip.legForDate(DateTime(2026, 12, 25)), isNull);
    });

    test('copyWith overrides only the given fields', () {
      final trip = buildTwoLegTrip();
      final renamed = trip.copyWith(name: 'Renamed Trip');
      expect(renamed.name, 'Renamed Trip');
      expect(renamed.id, trip.id);
      expect(renamed.legs, trip.legs);
    });
  });

  group('TripActivity', () {
    test('apiValue round-trips through tripActivityFromApiValue', () {
      for (final activity in TripActivity.values) {
        expect(tripActivityFromApiValue(activity.apiValue), activity);
      }
    });

    test('formalOccasion and waterActivities use snake_case wire values', () {
      expect(TripActivity.formalOccasion.apiValue, 'formal_occasion');
      expect(TripActivity.waterActivities.apiValue, 'water_activities');
    });

    test('tripActivityFromApiValue returns null for an unrecognized value', () {
      expect(tripActivityFromApiValue('skydiving'), isNull);
    });
  });
}
