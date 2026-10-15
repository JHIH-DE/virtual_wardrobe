import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/trip_details_page.dart';
import 'package:uwearis/features/pages/trips_page.dart';
import 'package:uwearis/features/widgets/common/main_nav_bar.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

class _FakeTrips extends TripsNotifier {
  _FakeTrips(this._items);
  final List<Trip> _items;

  @override
  Future<List<Trip>> build() async => _items;
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets(
    'no trips shows the "no trips planned" empty state, centered, with a '
    'Plan a Trip action that opens the new-trip dialog',
    (tester) async {
      await pumpApp(
        tester,
        const TripsPage(),
        overrides: [tripsProvider.overrideWith(() => _FakeTrips([]))],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No trips planned yet'), findsOneWidget);
      expect(
        find.text(
          'Plan a trip and let Uwearis help you pack and pick outfits.',
        ),
        findsOneWidget,
      );
      expect(find.text('Plan a Trip'), findsOneWidget);

      await tester.tap(find.text('Plan a Trip'));
      await tester.pumpAndSettle();

      // FieldLabel upper-cases it.
      expect(find.text('TRIP NAME'), findsOneWidget);
    },
  );

  testWidgets(
    'openTripDetails loads a trip only on its first visit — reopening it '
    'pushes Trip Details straight from the cache',
    (tester) async {
      var planRequests = 0;
      var tripRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/plan')) {
          planRequests++;
          return jsonResponse(envelope({'days': [], 'suitcase_items': []}));
        }
        if (request.url.path.endsWith('/trip_plans/7')) {
          tripRequests++;
          return jsonResponse(envelope({'suitcase_items': []}));
        }
        if (request.url.path.endsWith('/packing-analysis')) {
          return jsonResponse(
            envelope({'overall_advice': null, 'categories': []}),
          );
        }
        return jsonResponse(envelope({}), status: 404);
      });
      final trip = Trip(
        id: '7',
        name: 'Kyoto Autumn',
        activities: const [],
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
              end: DateTime(2026, 11, 2),
            ),
          ),
        ],
      );

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => openTripDetails(
                  context,
                  ref,
                  trip,
                  tab: MainTab.tripPlanner,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(TripDetailsPage), findsOneWidget);
        expect((planRequests, tripRequests), (1, 1));

        Navigator.of(tester.element(find.byType(TripDetailsPage))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('open'));
        await tester.pump();
        // Pushed on the very next frame, with nothing awaited first.
        expect(
          find.byType(TripDetailsPage, skipOffstage: false),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        expect((planRequests, tripRequests), (1, 1));
      }, () => client);
    },
  );
}
