import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/trip_plan.dart';
import 'package:uwearis/features/pages/trip_details_page.dart';
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
  // as the preloaded plan carries no stale image URLs and no push/pop
  // touches _fetchSuitcaseGarments/_refreshTripPlan (see the dedicated
  // regression test below for that pair).
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

  testWidgets('renders the trip header and suitcase section', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
      );
      await tester.pump(); // let _loadPackingAnalysis resolve
      await tester.pump();

      expect(find.text('Kyoto Autumn'), findsOneWidget);
      // Destinations header + the selected day's city subtitle.
      expect(find.text('Kyoto'), findsWidgets);
      expect(find.text('Suitcase'), findsOneWidget);
      // The outfit-advice card lives on the Suitcase page now, not here.
      expect(find.text('Layer up for the evenings.'), findsNothing);
    }, packingAdviceClient);
  });

  // Planning/updating the trip's outfits is TripSuitcasePage's job now (see
  // trip_suitcase_page_test.dart) — without a plan yet, this page's only
  // entry point into that flow is the wardrobe section's CTA card.
  testWidgets(
    'with no plan, the wardrobe section offers a CTA that opens the Suitcase '
    'page',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);

        await tester.tap(find.text('Let Uwearis Plan Your Trip'));
        await tester.pumpAndSettle();

        expect(find.byType(TripSuitcasePage), findsOneWidget);
      }, packingAdviceClient);
    },
  );

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
      await pumpApp(tester, TripDetailsPage(trip: _trip(), initialData: plan));
      await tester.pump();
      await tester.pump();

      expect(find.text('Daily Outfit Plan'), findsOneWidget);
    }, packingAdviceClient);
  });

  testWidgets('with no plan the outfit image card is hidden', (tester) async {
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

      // No "no image / no outfit planned" empty state before a plan exists.
      expect(find.text('No outfit image yet'), findsNothing);
      expect(find.text('No outfit planned yet'), findsNothing);
      expect(find.text('Generate Outfit'), findsNothing);
    }, packingAdviceClient);
  });

  testWidgets('a planned but unrendered day shows a Generate Outfit button', (
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
      await pumpApp(tester, TripDetailsPage(trip: _trip(), initialData: plan));
      await tester.pump();
      await tester.pump();

      // The per-day action is a button on the card, not on a bottom bar.
      expect(find.text('Generate Outfit'), findsOneWidget);
      expect(find.text('No outfit image yet'), findsNothing);
    }, packingAdviceClient);
  });

  // Regression test for the just-created-trip flow: TripsPage.handleCreateTrip
  // pushes TripSuitcasePage directly on top of this (already-pushed,
  // background) page — never through _openSuitcase — so only [didPopNext]
  // can catch the return. Plan generation itself now happens on that page,
  // so this exercises _refreshTripPlan (not just _fetchSuitcaseGarments,
  // covered by [_TripDetailsPageState._fetchSuitcaseGarments]'s own doc
  // comment / the suitcase-ids it feeds elsewhere).
  testWidgets(
    'popping back from a Suitcase page pushed directly on top of this page '
    '(the just-created-trip flow) refreshes the trip plan',
    (tester) async {
      // Toggled to simulate the plan having been generated while the user
      // was on the (directly-pushed) Suitcase page.
      var planGenerated = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/packing-analysis')) {
          return jsonResponse(
            envelope({'overall_advice': null, 'categories': []}),
          );
        }
        if (request.method == 'GET' && request.url.path.endsWith('/plan')) {
          if (!planGenerated) {
            return jsonResponse(envelope({'days': [], 'suitcase_items': []}));
          }
          return jsonResponse(
            envelope({
              'days': [
                {
                  'date': '2026-11-01',
                  'options': [
                    {
                      'id': 10,
                      'order_index': 0,
                      'items': [
                        {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
                      ],
                    },
                  ],
                },
              ],
              'suitcase_items': [
                {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
              ],
            }),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/trip_plans/7')) {
          return jsonResponse(
            envelope({
              'suitcase_items': [
                {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
              ],
            }),
          );
        }
        return jsonResponse(envelope({}), status: 404);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);

        // Mirrors TripsPage.handleCreateTrip: push the Suitcase page
        // straight onto the navigator, not via TripDetailsPage's own
        // _openSuitcase.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip())),
        );
        await tester.pumpAndSettle();

        // As if TripSuitcasePage's own "Plan Trip Outfits" button just
        // generated the plan and popped back.
        planGenerated = true;
        navigator.pop();
        await tester.pump();
        await tester.pump();

        expect(find.text('Generate Outfit'), findsOneWidget);
        expect(find.text('Let Uwearis Plan Your Trip'), findsNothing);
      }, () => client);
    },
  );
}
