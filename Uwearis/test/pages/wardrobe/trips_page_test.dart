import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/wardrobe/trip_details_page.dart';
import 'package:uwearis/features/pages/wardrobe/trips_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/common/wardrobe_nav_bar.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/mock_http.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

void main() {
  setUp(setUpFakeAuth);

  testWidgets(
    'no trips shows the "no trips planned" empty state, centered, with a '
    'Plan a Trip action that opens the new-trip dialog',
    (tester) async {
      await pumpApp(
        tester,
        const TripsPage(),
        overrides: [tripsProvider.overrideWith(() => SeededTripsNotifier([]))],
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
      var outfitRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/trip_plans/7/outfits/sync')) {
          outfitRequests++;
          return jsonResponse(
            envelope({'outfits': [], 'suitcase_items': [], 'total_days': 2}),
          );
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
                  tab: WardrobeTab.tripPlanner,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(TripDetailsPage), findsOneWidget);
        expect(outfitRequests, 1);

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
        expect(outfitRequests, 1);
      }, () => client);
    },
  );

  // P2-2: deleting from a list card (Trips; Home shares handleDeleteTrip).
  // TripsPage sits on a base page, so a pop of one route too many shows.
  group('delete a trip from its card', () {
    final kyoto = Trip(
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
            start: DateTime(2030, 11, 1),
            end: DateTime(2030, 11, 2),
          ),
        ),
      ],
    );

    late List<http.Request> deletes;
    late Completer<http.Response>? hold;
    late http.Response Function() reply;

    setUp(() {
      deletes = [];
      hold = null;
      reply = () => jsonResponse(envelope(null));
    });

    MockClient client() => MockClient((request) async {
      if (request.method == 'DELETE') {
        deletes.add(request);
        final gate = hold;
        if (gate != null) return gate.future;
        return reply();
      }
      if (request.url.path.endsWith('/auth/refresh')) {
        return jsonResponse({'success': false}, status: 401);
      }
      return jsonResponse(envelope({}), status: 404);
    });

    Future<void> openTrips(WidgetTester tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripsPage()),
              ),
              child: const Text('base page'),
            ),
          ),
        ),
        overrides: [
          tripsProvider.overrideWith(() => SeededTripsNotifier([kyoto])),
        ],
      );
      await tester.tap(find.text('base page'));
      await tester.pumpAndSettle();
      expect(find.text('Kyoto Autumn'), findsOneWidget);
    }

    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pump();
    }

    /// Closes Session Expired, releasing AuthExpiredHandler's static guard
    /// for the next test; the login page it opens may log plugin errors.
    Future<void> dismissSessionExpired(WidgetTester tester) async {
      await tester.tap(find.byKey(AppDialog.dismissButtonKey).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      while (tester.takeException() != null) {}
    }

    Future<void> finish(WidgetTester tester) async {
      hold?.complete(jsonResponse(envelope(null)));
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('B1: a system back during the delete neither closes the '
        'overlay nor, once it lands, closes the page beneath it', (
      tester,
    ) async {
      hold = Completer();
      await http.runWithClient(() async {
        await openTrips(tester);
        await confirmDelete(tester);
        expect(find.byType(LoadingOverlay), findsOneWidget);

        await tester.binding.handlePopRoute(); // Android back
        await tester.pump();
        final overlayAfterBack = find.byType(LoadingOverlay).evaluate().length;

        await finish(tester);
        expect(
          {
            'overlay after back': overlayAfterBack,
            'overlay after delete': find
                .byType(LoadingOverlay)
                .evaluate()
                .length,
            'TripsPage after delete': find.byType(TripsPage).evaluate().length,
          },
          {
            'overlay after back': 1,
            'overlay after delete': 0,
            'TripsPage after delete': 1,
          },
        );
        expect(find.text('Kyoto Autumn'), findsNothing, reason: 'removed');
      }, client);
    });

    testWidgets('success removes the trip, closing only the overlay', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await openTrips(tester);
        await confirmDelete(tester);
        await tester.pumpAndSettle();

        expect(deletes, hasLength(1));
        expect(find.byType(LoadingOverlay), findsNothing);
        expect(find.byType(TripsPage), findsOneWidget);
        expect(find.text('Kyoto Autumn'), findsNothing);
      }, client);
    });

    testWidgets('B2: a retry finding the trip already gone (404 '
        'TRIP_NOT_FOUND) removes it, with no error', (tester) async {
      reply = () => jsonResponse({
        'success': false,
        'message': 'gone',
        'data': null,
        'error_code': 'TRIP_NOT_FOUND',
      }, status: 404);
      await http.runWithClient(() async {
        await openTrips(tester);
        await confirmDelete(tester);
        await tester.pumpAndSettle();

        expect(deletes, hasLength(1));
        expect(find.text('Failed to delete trip'), findsNothing);
        expect(find.byType(LoadingOverlay), findsNothing);
        expect(find.byType(TripsPage), findsOneWidget);
        expect(find.text('Kyoto Autumn'), findsNothing);
      }, client);
    });

    testWidgets('a failure shows the existing error and keeps the trip', (
      tester,
    ) async {
      reply = () => jsonResponse({
        'success': false,
        'message': 'boom',
        'data': null,
        'error_code': 'INTERNAL_SERVER_ERROR',
      }, status: 500);
      await http.runWithClient(() async {
        await openTrips(tester);
        await confirmDelete(tester);
        await tester.pumpAndSettle();

        expect(find.text('Failed to delete trip'), findsOneWidget);
        expect(find.byType(LoadingOverlay), findsNothing);
        expect(find.byType(TripsPage), findsOneWidget);
        expect(find.text('Kyoto Autumn'), findsOneWidget);
      }, client);
    });

    testWidgets('an expired session closes only the overlay before the '
        'session-expired flow takes over', (tester) async {
      reply = () => jsonResponse({'success': false}, status: 401);
      await http.runWithClient(() async {
        await openTrips(tester);
        await confirmDelete(tester);
        await tester.pumpAndSettle();

        expect(find.text('Session Expired'), findsOneWidget);
        expect(find.byType(LoadingOverlay), findsNothing);
        expect(find.byType(TripsPage), findsOneWidget, reason: 'not popped');
        await dismissSessionExpired(tester);
      }, client);
    });

    testWidgets('the page going away mid-delete leaves no overlay and no '
        'error', (tester) async {
      hold = Completer();
      await http.runWithClient(() async {
        await openTrips(tester);
        final tripsRoute = ModalRoute.of(
          tester.element(find.byType(TripsPage)),
        )!;
        await confirmDelete(tester);
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .removeRoute(tripsRoute);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TripsPage), findsNothing, reason: 'disposed');

        await finish(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(LoadingOverlay), findsNothing);
        expect(find.text('base page'), findsOneWidget);
      }, client);
    });

    // F2: the overlay used to be closed only while it was the top route, so
    // anything pushed over it mid-delete left it behind, blocking back.
    group('a route pushed over the overlay mid-delete', () {
      final overlay = find.byType(LoadingOverlay);
      final onTop = find.text('On top');

      BuildContext tripsContext(WidgetTester tester) =>
          tester.element(find.byType(TripsPage));

      bool tripsIsTop(WidgetTester tester) =>
          ModalRoute.of(tripsContext(tester))?.isCurrent ?? false;

      /// Its dots never settle, so fixed pumps while it may still be up.
      Future<void> pumpRoutes(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<void> coverWithDialog(WidgetTester tester) async {
        unawaited(
          showDialog<void>(
            context: tripsContext(tester),
            builder: (_) => const AlertDialog(content: Text('On top')),
          ),
        );
        await pumpRoutes(tester);
        expect(onTop, findsOneWidget);
        expect(overlay, findsOneWidget);
      }

      Future<void> land(WidgetTester tester, http.Response response) async {
        hold!.complete(response);
        await pumpRoutes(tester);
      }

      testWidgets('success: the overlay leaves from under it, the route on '
          'top stays, and back works once that closes', (tester) async {
        hold = Completer();
        await http.runWithClient(() async {
          await openTrips(tester);
          await confirmDelete(tester);
          await coverWithDialog(tester);

          await land(tester, jsonResponse(envelope(null)));
          expect(overlay, findsNothing);
          expect(onTop, findsOneWidget);
          expect(find.text('Kyoto Autumn'), findsNothing, reason: 'removed');

          Navigator.of(tester.element(onTop)).pop();
          await tester.pumpAndSettle();
          expect(tripsIsTop(tester), isTrue);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(TripsPage), findsNothing);
          expect(find.text('base page'), findsOneWidget);
        }, client);
      });

      testWidgets('failure: the overlay leaves, the error shows over the '
          'route on top, and the trip is kept', (tester) async {
        hold = Completer();
        await http.runWithClient(() async {
          await openTrips(tester);
          await confirmDelete(tester);
          await coverWithDialog(tester);

          await land(
            tester,
            jsonResponse({
              'success': false,
              'message': 'boom',
              'data': null,
              'error_code': 'INTERNAL_SERVER_ERROR',
            }, status: 500),
          );
          expect(overlay, findsNothing);
          expect(onTop, findsOneWidget);
          expect(find.text('Failed to delete trip'), findsOneWidget);
          expect(find.byType(TripsPage), findsOneWidget);

          await tester.tap(find.byKey(AppDialog.dismissButtonKey));
          await tester.pumpAndSettle();
          Navigator.of(tester.element(onTop)).pop();
          await tester.pumpAndSettle();
          expect(tripsIsTop(tester), isTrue);
          expect(find.text('Kyoto Autumn'), findsOneWidget);
        }, client);
      });

      testWidgets('the session expired elsewhere: the late reply removes '
          'only the overlay, under Session Expired, and changes nothing else', (
        tester,
      ) async {
        hold = Completer();
        await http.runWithClient(() async {
          await openTrips(tester);
          await confirmDelete(tester);
          unawaited(AuthExpiredHandler.handle(tripsContext(tester)));
          // clearSignedInSession's async steps, then the dialog's entrance.
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.text('Session Expired'), findsOneWidget);

          await land(tester, jsonResponse(envelope(null)));
          expect(overlay, findsNothing);
          expect(find.text('Session Expired'), findsOneWidget);
          expect(find.text('Failed to delete trip'), findsNothing);
          expect(find.byType(TripsPage), findsOneWidget, reason: 'not popped');
          expect(
            find.text('Kyoto Autumn', skipOffstage: false),
            findsOneWidget,
            reason: "the old session's reply doesn't touch the list",
          );
          await dismissSessionExpired(tester);
        }, client);
      });

      testWidgets('signed out meanwhile: the late reply pops nothing off the '
          'new stack', (tester) async {
        hold = Completer();
        await http.runWithClient(() async {
          await openTrips(tester);
          await confirmDelete(tester);
          final navigator = Navigator.of(tripsContext(tester));
          await clearSignedInSession();
          unawaited(
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Signed out')),
              ),
              (_) => false,
            ),
          );
          await tester.pumpAndSettle();
          expect(overlay, findsNothing);

          await land(tester, jsonResponse(envelope(null)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Signed out'), findsOneWidget);
          expect(find.text('Failed to delete trip'), findsNothing);
        }, client);
      });
    });

    testWidgets('a second tap on Delete sends no second request', (
      tester,
    ) async {
      hold = Completer();
      await http.runWithClient(() async {
        await openTrips(tester);
        await confirmDelete(tester);
        await tester.tapAt(tester.getCenter(find.byType(LoadingOverlay)));
        await tester.pump();

        expect(deletes, hasLength(1));
        await finish(tester);
        expect(deletes, hasLength(1));
      }, client);
    });
  });
}
