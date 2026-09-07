import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/trip_suitcase_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

Trip _trip() => Trip(
  id: '7',
  name: 'Kyoto Autumn',
  activities: const ['sightseeing'],
  legs: [
    TripLeg(
      location: LocationResult(
        name: 'Kyoto',
        latitude: 35,
        longitude: 135,
        timezone: 'Asia/Tokyo',
      ),
      dateRange: DateTimeRange(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 4),
      ),
    ),
  ],
);

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  http.Client suitcaseClient() {
    return MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/trip_plans/7')) {
        return jsonResponse(
          envelope({
            'suitcase_items': [
              {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
              {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
            ],
          }),
        );
      }
      return jsonResponse(envelope({}), status: 404);
    });
  }

  testWidgets('renders the packed suitcase items', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Tee'), findsOneWidget);
      expect(find.text('Jeans'), findsOneWidget);
    }, suitcaseClient);
  });
}
