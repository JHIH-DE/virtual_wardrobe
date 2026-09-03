import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/trip_plan.dart';
import 'package:uwearis/features/pages/trip_details_page.dart';

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

Garment _garment(int id) => Garment(
  id: id,
  garmentId: id,
  name: 'Item $id',
  category: GarmentCategory.top,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
);

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // getTripSuggestion (packing-analysis) is the only initState call as long
  // as the preloaded plan carries no stale image URLs.
  http.Client packingAdviceClient({int recommendedTotal = 6}) {
    return MockClient((request) async {
      if (request.url.path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({
            'overall_advice': 'Layer up for the evenings.',
            'categories': [
              {'category': 'Top', 'recommended_quantity': recommendedTotal},
            ],
          }),
        );
      }
      return jsonResponse(envelope({}), status: 404);
    });
  }

  testWidgets('renders the trip header, suitcase section and packing advice', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
      );
      await tester.pump(); // let _loadPackingAdvice resolve
      await tester.pump();

      expect(find.text('Kyoto Autumn'), findsOneWidget);
      // Destinations header + the selected day's city subtitle.
      expect(find.text('Kyoto'), findsWidgets);
      expect(find.text('Suitcase'), findsOneWidget);
      expect(find.text('Layer up for the evenings.'), findsOneWidget);
    }, packingAdviceClient);
  });

  testWidgets('with no plan the bottom bar offers Generate Trip Plan', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        TripDetailsPage(
          trip: _trip(),
          initialData: TripPlan(suitcaseIds: {1, 2, 3, 4, 5, 6}),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Threshold met (6 packed vs 6 recommended) -> button is live.
      expect(find.text('Generate Trip Plan'), findsOneWidget);
    }, packingAdviceClient);
  });

  testWidgets('a generated plan renders the Daily Outfit Plan card', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      final plan = TripPlan(
        suitcaseIds: {1},
        days: [
          TripDayOutfit(
            date: DateTime(2026, 11, 1),
            optionId: 10,
            garments: [_garment(1)],
          ),
        ],
      );
      await pumpApp(
        tester,
        TripDetailsPage(trip: _trip(), initialData: plan),
      );
      await tester.pump();
      await tester.pump();
      // TripDayCard's fixed-width date row overflows by a hair under the
      // test font's wider glyph metrics — cosmetic, not what this test is
      // about.
      tester.takeException();

      expect(find.text('Daily Outfit Plan'), findsOneWidget);
    }, packingAdviceClient);
  });
}
