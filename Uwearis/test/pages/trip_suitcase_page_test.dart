import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/expandable_insight_body.dart';

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

  http.Client suitcaseClient({
    String? overallAdvice,
    List<Map<String, dynamic>> suitcaseItems = const [
      {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
      {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
    ],
    List<Map<String, dynamic>> closetGarments = const [],
  }) {
    return MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/trip_plans/7')) {
        return jsonResponse(envelope({'suitcase_items': suitcaseItems}));
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({'overall_advice': overallAdvice, 'categories': []}),
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/garments')) {
        return jsonResponse(envelope(closetGarments));
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
    }, () => suitcaseClient());
  });

  // The outfit-advice card moved here from Trip Details — this page now
  // watches tripSuggestionProvider directly (see trip_suggestion_provider.dart).
  testWidgets('renders the outfit-advice card, collapsed by default', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Layer up for the evenings.'), findsOneWidget);
      expect(
        tester
            .widget<ExpandableInsightBody>(find.byType(ExpandableInsightBody))
            .expanded,
        isFalse,
      );
    }, () => suitcaseClient(overallAdvice: 'Layer up for the evenings.'));
  });

  testWidgets('justCreated opens the outfit-advice card expanded', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip(), justCreated: true));
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<ExpandableInsightBody>(find.byType(ExpandableInsightBody))
            .expanded,
        isTrue,
      );
    }, () => suitcaseClient(overallAdvice: 'Layer up for the evenings.'));
  });

  testWidgets(
    'an empty suitcase shows the "start packing" state, and its Add '
    'Garments button opens the garment picker',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, TripSuitcasePage(trip: _trip()));
        await tester.pump();
        await tester.pump();

        expect(find.text('Start packing your trip'), findsOneWidget);
        expect(
          find.text(
            'Choose clothes from your closet to build your trip outfits.',
          ),
          findsOneWidget,
        );
        expect(find.text('Add Garments'), findsOneWidget);

        await tester.tap(find.byType(AccentPillButton));
        await tester.pumpAndSettle();

        expect(find.text('Select Garments'), findsOneWidget);
      }, () => suitcaseClient(suitcaseItems: const []));
    },
  );

  testWidgets(
    'the empty-suitcase content stays put on screen whether the advice '
    'card above it is collapsed or expanded',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, TripSuitcasePage(trip: _trip()));
        await tester.pump();
        await tester.pump();

        final collapsedCenter = tester.getCenter(
          find.text('Start packing your trip'),
        );

        await tester.tap(find.byType(ExpandableInsightBody));
        await tester.pumpAndSettle();

        final expandedCenter = tester.getCenter(
          find.text('Start packing your trip'),
        );

        expect(expandedCenter, collapsedCenter);
      }, () => suitcaseClient(
        suitcaseItems: const [],
        overallAdvice: 'Layer up for the evenings.',
      ));
    },
  );
}
