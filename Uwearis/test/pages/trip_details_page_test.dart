import 'dart:async';

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

// A closet-shaped JSON garment (as returned by GET /garments), for feeding
// garmentsProvider — this is what _hasViableSuitcase/_suitcaseIsViable
// actually reads to decide whether Generate Trip Plan can go live.
Map<String, dynamic> _closetGarmentJson(int id, GarmentCategory category) => {
  'id': id,
  'name': 'Item $id',
  'category': category.apiValue,
  'sub_category': '',
  'image_url': '',
};

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // getTripSuggestion (packing-analysis) is the only initState call as long
  // as the preloaded plan carries no stale image URLs. [closetGarments], if
  // given, backs GET /garments — [_suitcaseIsViable] reads the closet
  // (filtered to the suitcase ids) to decide whether Generate Trip Plan can
  // go live, so tests of that gate need it populated.
  http.Client packingAdviceClient({
    int recommendedTotal = 6,
    List<Map<String, dynamic>> closetGarments = const [],
    // Backs GET /trip_plans/7 (TripService.getTrip), which
    // _fetchSuitcaseGarments (and so [didPopNext]) reads to refresh
    // _suitcaseIds — see the "pushed directly on top" regression test.
    List<Map<String, dynamic>> suitcaseItems = const [],
  }) {
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
      if (request.method == 'GET' && request.url.path.endsWith('/garments')) {
        return jsonResponse(envelope(closetGarments));
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/trip_plans/7')) {
        return jsonResponse(envelope({'suitcase_items': suitcaseItems}));
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

      // The suitcase can build a complete outfit (top+bottom+shoes among
      // the 6 packed ids) -> button is live.
      expect(find.text('Generate Trip Plan'), findsOneWidget);
    }, () => packingAdviceClient(closetGarments: [
      _closetGarmentJson(1, GarmentCategory.top),
      _closetGarmentJson(2, GarmentCategory.bottom),
      _closetGarmentJson(3, GarmentCategory.shoes),
      _closetGarmentJson(4, GarmentCategory.outer),
      _closetGarmentJson(5, GarmentCategory.socks),
      _closetGarmentJson(6, GarmentCategory.accessory),
    ]));
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

      // The per-day action is a button on the card, not on the bottom bar.
      expect(find.text('Generate Outfit'), findsOneWidget);
      expect(find.text('No outfit image yet'), findsNothing);
    }, packingAdviceClient);
  });

  // recommended_quantity is packing guidance only — see _isPlanReady /
  // _hasViableSuitcase in trip_details_page.dart. Generate Trip Plan cares
  // only about whether the suitcase can build a complete outfit (top +
  // bottom, or a one-piece, plus shoes), mirroring the backend's own
  // /generate minimum (DayPlanGenerator.generate_days_payload).
  testWidgets(
    'a suitcase well under the recommended count still offers Generate '
    'Trip Plan, as long as it can build a complete outfit',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(
            trip: _trip(),
            // 3 packed vs. a recommended 6 — under the old count-based gate
            // this would have stayed hidden.
            initialData: TripPlan(suitcaseIds: {1, 2, 3}),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const ValueKey('bottomActionButton-visible')),
          findsOneWidget,
        );
      }, () => packingAdviceClient(closetGarments: [
        _closetGarmentJson(1, GarmentCategory.top),
        _closetGarmentJson(2, GarmentCategory.bottom),
        _closetGarmentJson(3, GarmentCategory.shoes),
      ]));
    },
  );

  testWidgets(
    'a suitcase that cannot build a complete outfit (no shoes) keeps '
    'Generate Trip Plan hidden, regardless of the recommended count',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(
            trip: _trip(),
            initialData: TripPlan(suitcaseIds: {1, 2}),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const ValueKey('bottomActionButton-hidden')),
          findsOneWidget,
        );
      }, () => packingAdviceClient(closetGarments: [
        _closetGarmentJson(1, GarmentCategory.top),
        _closetGarmentJson(2, GarmentCategory.bottom),
      ]));
    },
  );

  // _isPlanReady must fail-closed while _suitcaseIsViable is still null
  // (garmentsProvider hasn't resolved yet) — "not yet verified" must not
  // render as "ready". Holds GET /garments open with a Completer so the
  // test can observe the in-between state before letting it resolve.
  testWidgets(
    'while the closet is still loading, Generate Trip Plan stays hidden '
    '(fail-closed, not fail-open)',
    (tester) async {
      final garmentsGate = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/packing-analysis')) {
          return jsonResponse(
            envelope({'overall_advice': null, 'categories': []}),
          );
        }
        if (request.method == 'GET' && request.url.path.endsWith('/garments')) {
          return garmentsGate.future;
        }
        return jsonResponse(envelope({}), status: 404);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(
            trip: _trip(),
            initialData: TripPlan(suitcaseIds: {1, 2, 3}),
          ),
        );
        await tester.pump(); // packing-analysis resolves
        await tester.pump();

        // GET /garments is still pending -> _suitcaseIsViable is null.
        expect(
          find.byKey(const ValueKey('bottomActionButton-hidden')),
          findsOneWidget,
        );

        garmentsGate.complete(
          jsonResponse(
            envelope([
              _closetGarmentJson(1, GarmentCategory.top),
              _closetGarmentJson(2, GarmentCategory.bottom),
              _closetGarmentJson(3, GarmentCategory.shoes),
            ]),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Now resolved and viable -> the CTA appears.
        expect(
          find.byKey(const ValueKey('bottomActionButton-visible')),
          findsOneWidget,
        );
      }, () => client);
    },
  );

  // Regression test for the just-created-trip flow: TripsPage.handleCreateTrip
  // pushes TripSuitcasePage directly on top of this (already-pushed,
  // background) page — never through _openSuitcase — so only [didPopNext]
  // can catch the return and refresh _suitcaseIds.
  testWidgets(
    'popping back from a Suitcase page pushed directly on top of this page '
    '(the just-created-trip flow) refreshes the suitcase, so Generate Trip '
    'Plan appears once packing is viable',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
        );
        await tester.pump();
        await tester.pump();

        // Nothing packed at preload time -> hidden.
        expect(
          find.byKey(const ValueKey('bottomActionButton-hidden')),
          findsOneWidget,
        );

        // Mirrors TripsPage.handleCreateTrip: push the Suitcase page
        // straight onto the navigator, not via TripDetailsPage's own
        // _openSuitcase.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip())),
        );
        await tester.pumpAndSettle();

        // Pop back to Trip Details — by the time this resolves, the suitcase
        // (per the mocked GET /trip_plans/7) holds a viable outfit.
        navigator.pop();
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const ValueKey('bottomActionButton-visible')),
          findsOneWidget,
        );
      }, () => packingAdviceClient(
        closetGarments: [
          _closetGarmentJson(1, GarmentCategory.top),
          _closetGarmentJson(2, GarmentCategory.bottom),
          _closetGarmentJson(3, GarmentCategory.shoes),
        ],
        suitcaseItems: [
          {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
          {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
          {'garment_id': 3, 'name': 'Sneakers', 'category': 'shoes'},
        ],
      ));
    },
  );
}
