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
    void Function()? onGenerate,
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
        return jsonResponse(
          envelope({
            'items': closetGarments,
            'total': closetGarments.length,
            'page': 1,
            'size': 100,
          }),
        );
      }
      if (request.method == 'POST' && request.url.path.endsWith('/generate')) {
        onGenerate?.call();
        return jsonResponse(envelope({'days': [], 'suitcase_items': suitcaseItems}));
      }
      if (request.method == 'DELETE' &&
          request.url.path.contains('/suitcase-items/')) {
        return jsonResponse(envelope(null));
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

  // Plan-generation moved here from Trip Details — see trip_details_page.dart
  // and its own test's "the wardrobe section offers a CTA" case.
  group('plan generation', () {
    final viableSuitcase = [
      {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
      {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
      {'garment_id': 3, 'name': 'Sneakers', 'category': 'shoes'},
    ];
    // Same minimum viable set plus one extra item that isn't load-bearing —
    // removing it leaves top+bottom+shoes intact (still viable) while still
    // changing the packed set relative to what it was on open.
    final viableSuitcaseWithExtra = [
      ...viableSuitcase,
      {'garment_id': 4, 'name': 'Cap', 'category': 'accessory'},
    ];

    /// Removes the last packed card (Accessory sorts last in
    /// [_TripSuitcasePageState._categoryOrder], so with
    /// [viableSuitcaseWithExtra] this is always "Cap") via its corner "×"
    /// badge + the REMOVE confirm — puts the suitcase in a "changed since
    /// open" state without disturbing the minimum viable top+bottom+shoes.
    Future<void> removeLastPackedCard(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('REMOVE'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'shows "Plan Trip Outfits" once the suitcase can build a complete '
      'outfit, with no plan yet',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          expect(find.text('Plan Trip Outfits'), findsOneWidget);
        }, () => suitcaseClient(suitcaseItems: viableSuitcase));
      },
    );

    testWidgets(
      'hides the plan button while the suitcase cannot build a complete '
      'outfit',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          // Default suitcaseItems: top + bottom, no shoes -> not viable.
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          expect(
            find.byKey(const ValueKey('bottomActionButton-hidden')),
            findsOneWidget,
          );
          expect(find.text('Plan Trip Outfits'), findsNothing);
        }, () => suitcaseClient());
      },
    );

    testWidgets(
      'a plan already existing is not enough on its own — the button stays '
      'hidden until the suitcase actually changes since opening',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
          );
          await tester.pump();
          await tester.pump();

          expect(
            find.byKey(const ValueKey('bottomActionButton-hidden')),
            findsOneWidget,
          );
          expect(find.text('Update Trip Outfits'), findsNothing);
        }, () => suitcaseClient(suitcaseItems: viableSuitcase));
      },
    );

    testWidgets(
      'shows "Update Trip Outfits" once the packed set changes since '
      'opening (e.g. removing a packed item)',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
          );
          await tester.pump();
          await tester.pump();
          expect(find.text('Update Trip Outfits'), findsNothing);

          await removeLastPackedCard(tester);

          expect(find.text('Update Trip Outfits'), findsOneWidget);
        }, () => suitcaseClient(suitcaseItems: viableSuitcaseWithExtra));
      },
    );

    testWidgets(
      'tapping "Plan Trip Outfits" generates the plan and pops back',
      (tester) async {
        var generateCalls = 0;
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            Scaffold(body: const Text('Behind the Suitcase page')),
          );
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          navigator.push(
            MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip())),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Plan Trip Outfits'));
          await tester.pumpAndSettle();

          expect(generateCalls, 1);
          expect(find.byType(TripSuitcasePage), findsNothing);
          expect(find.text('Behind the Suitcase page'), findsOneWidget);
        }, () => suitcaseClient(
          suitcaseItems: viableSuitcase,
          onGenerate: () => generateCalls++,
        ));
      },
    );

    testWidgets(
      'tapping "Update Trip Outfits" confirms before overwriting an '
      'existing plan',
      (tester) async {
        var generateCalls = 0;
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
          );
          await tester.pump();
          await tester.pump();
          await removeLastPackedCard(tester); // put it in a "changed" state

          await tester.tap(find.text('Update Trip Outfits'));
          await tester.pumpAndSettle();

          expect(find.text('Regenerate outfit plan?'), findsOneWidget);
          // Cancel -> no generate call, still on the Suitcase page.
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();

          expect(generateCalls, 0);
          expect(find.byType(TripSuitcasePage), findsOneWidget);
        }, () => suitcaseClient(
          suitcaseItems: viableSuitcaseWithExtra,
          onGenerate: () => generateCalls++,
        ));
      },
    );
  });
}
