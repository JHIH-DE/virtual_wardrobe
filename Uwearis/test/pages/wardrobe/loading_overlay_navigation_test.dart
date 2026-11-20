import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/app/wardrobe_shell.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/wardrobe/create_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/trip_details_page.dart';
import 'package:uwearis/features/pages/wardrobe/trip_suitcase_page.dart';
import 'package:uwearis/features/pages/wardrobe/trips_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/trip/trip_create_dialog.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';

// A2-Nav: openAddOutfit and handleCreateTrip close their LoadingOverlay
// after an await. Closing "whatever is on top" can close Session Expired,
// the login page, or the page beneath instead.

final _sessionExpired = find.text('Session Expired');
final _garmentsFailed = find.text('Failed to load garments');
final _tripFailed = find.text('Failed to create trip');
final _overlay = find.byType(LoadingOverlay);
final _basePage = find.text('Base page', skipOffstage: false);

Map<String, dynamic> _collectionJson(int tripId) => {
  'trip_id': tripId,
  'total_days': 3,
  'suggested_outfit_count': {'min': 3, 'max': 4},
  'suitcase_items': <Object>[],
  'outfits': <Object>[],
  'refresh_batch_size': 0,
  'ai_added_count': 0,
  'ai_status': 'no_new',
};

final _tripInput = Trip(
  id: '',
  name: 'Kyoto',
  activities: const [],
  legs: [
    TripLeg(
      location: LocationResult(
        name: 'Kyoto',
        latitude: 35.01,
        longitude: 135.77,
        timezone: 'Asia/Tokyo',
      ),
      dateRange: DateTimeRange(
        start: DateTime(2027, 3, 1),
        end: DateTime(2027, 3, 3),
      ),
    ),
  ],
);

/// Holds the entry point's own request ([heldPath], [heldMethod]) until
/// [release]; everything else answers at once with an empty success.
class _Backend {
  _Backend({required this.heldPath, required this.heldMethod});
  final String heldPath;
  final String heldMethod;
  final _held = <Completer<http.Response>>[];
  final requests = <http.Request>[];

  /// Answers a request before the defaults when it returns non-null.
  Future<http.Response>? Function(http.Request)? before;
  http.Response Function()? _reply;

  bool _isHeld(http.Request r) =>
      r.method == heldMethod && r.url.path.endsWith(heldPath);

  int get heldCount => _held.length;

  /// Answers the held request, and any retry of it, with [reply].
  void release(http.Response Function() reply) {
    _reply = reply;
    for (final c in _held) {
      if (!c.isCompleted) c.complete(reply());
    }
  }

  MockClient client() => MockClient((req) async {
    requests.add(req);
    final early = before?.call(req);
    if (early != null) return early;
    if (_isHeld(req)) {
      final reply = _reply;
      if (reply != null) return reply();
      final c = Completer<http.Response>();
      _held.add(c);
      return c.future;
    }
    if (req.url.path.endsWith('/auth/refresh')) {
      return http.Response('{}', 401);
    }
    if (req.url.path.contains('/trip_plans/')) {
      return jsonResponse(envelope(_collectionJson(42)));
    }
    return jsonResponse(envelope({'items': <Object>[]}));
  });
}

void main() {
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
  });

  late BuildContext baseContext;
  late WidgetRef baseRef;

  /// Root → Base page; the entry point runs from Base page's context, as
  /// from a pushed page or the shell.
  ///
  /// [asHome] makes Base page the first route instead, as the shell is
  /// (Create Outfit's back goes to the first route). [watchTrips] keeps the
  /// trip list loaded, as the shell's Trips tab does.
  Future<void> pumpBase(
    WidgetTester tester, {
    bool watchCloset = false,
    bool watchTrips = false,
    bool asHome = false,
  }) async {
    final base = Consumer(
      builder: (context, ref, _) {
        // The shell's tabs keep these listened to, which is also what lets
        // appRetryPolicy's retries run.
        if (watchCloset) ref.watch(garmentsProvider);
        if (watchTrips) ref.watch(tripsProvider);
        baseContext = context;
        baseRef = ref;
        return const Scaffold(body: Text('Base page'));
      },
    );
    await pumpApp(
      tester,
      asHome ? base : const Scaffold(body: Text('Root')),
      retry: (_, _) => null,
    );
    if (!asHome) {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push(MaterialPageRoute(builder: (_) => base)));
    }
    await tester.pumpAndSettle();
  }

  /// garmentsProvider retries a 5xx (appRetryPolicy, ~2.9s in all).
  Future<void> settleRetries(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  void drainLoginPageErrors(WidgetTester tester) {
    while (tester.takeException() != null) {}
  }

  /// Closes Session Expired, releasing the handler's static guard.
  Future<void> dismissSessionExpired(WidgetTester tester) async {
    await tester.tap(find.byKey(AppDialog.dismissButtonKey).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    drainLoginPageErrors(tester);
  }

  /// Another of A's requests came back unrecoverable; its page handled it.
  Future<void> expireSessionElsewhere(WidgetTester tester) async {
    unawaited(AuthExpiredHandler.handle(baseContext));
    await tester.pump();
    await tester.pump();
    expect(_sessionExpired, findsOneWidget);
  }

  /// What Settings' Log out does after its confirm.
  Future<void> signOut(WidgetTester tester) async {
    final navigator = Navigator.of(baseContext);
    await clearSignedInSession();
    unawaited(
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      ),
    );
  }

  group('openAddOutfit', () {
    _Backend backend() => _Backend(heldPath: '/garments', heldMethod: 'GET');

    Future<void> start(WidgetTester tester, {bool asHome = false}) async {
      await pumpBase(tester, watchCloset: true, asHome: asHome);
      unawaited(openAddOutfit(baseContext, baseRef));
      await tester.pump();
      expect(_overlay, findsOneWidget);
    }

    testWidgets('session expired meanwhile: the late reply leaves Session '
        'Expired up, adds no error, and leaves no overlay behind', (
      tester,
    ) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await expireSessionElsewhere(tester);

        b.release(() => jsonResponse(envelope({'items': <Object>[]})));
        await tester.pump();
        // A route removed from under another one leaves on a later frame.
        await tester.pump(const Duration(milliseconds: 500));

        expect(_sessionExpired, findsOneWidget);
        expect(_garmentsFailed, findsNothing);
        expect(_overlay, findsNothing);
        expect(_basePage, findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);

        await dismissSessionExpired(tester);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(_overlay, findsNothing);
      }, b.client);
    });

    testWidgets('sign-out meanwhile: the late reply pops nothing off the '
        'login page and shows no error', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await signOut(tester);
        await tester.pump();
        b.release(() => jsonResponse(envelope({'items': <Object>[]})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        drainLoginPageErrors(tester);

        expect(find.byType(LoginPage), findsOneWidget);
        expect(_garmentsFailed, findsNothing);
        expect(_sessionExpired, findsNothing);
        expect(_overlay, findsNothing);
      }, b.client);
    });

    testWidgets('its own unrecoverable 401 still closes the overlay and '
        'goes to Session Expired', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        b.release(() => http.Response('{}', 401));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(_overlay, findsNothing);
        expect(_sessionExpired, findsOneWidget);
        expect(_garmentsFailed, findsNothing);
        await dismissSessionExpired(tester);
      }, b.client);
    });

    testWidgets('a 500 closes only the overlay and shows the error', (
      tester,
    ) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        b.release(() => jsonResponse(envelope(null), status: 500));
        await settleRetries(tester);

        expect(_overlay, findsNothing);
        expect(_garmentsFailed, findsOneWidget);
        expect(_basePage, findsOneWidget);
      }, b.client);
    });

    testWidgets('success closes only the overlay and opens Create Outfit '
        'over the page', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        b.release(() => jsonResponse(envelope({'items': <Object>[]})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(_overlay, findsNothing);
        expect(find.byType(CreateOutfitPage), findsOneWidget);
        expect(_basePage, findsOneWidget);
      }, b.client);
    });

    testWidgets('an overlay already closed by a system back: the reply pops '
        'nothing else', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));
        expect(_overlay, findsNothing);

        b.release(() => jsonResponse(envelope(null), status: 500));
        await settleRetries(tester);

        expect(_basePage, findsOneWidget);
        expect(_garmentsFailed, findsOneWidget);
      }, b.client);
    });

    testWidgets('opened twice before the closet loads: each closes its own '
        'overlay, none is left behind', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        unawaited(openAddOutfit(baseContext, baseRef));
        await tester.pump();
        expect(_overlay, findsNWidgets(2));
        expect(b.heldCount, 1, reason: 'both wait on one provider load');

        b.release(() => jsonResponse(envelope(null), status: 500));
        await settleRetries(tester);

        expect(_overlay, findsNothing);
        expect(_basePage, findsOneWidget);
      }, b.client);
    });

    testWidgets('success, then back from Create Outfit: back on the page it '
        'was opened from, no overlay left at any step', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester, asHome: true);
        b.release(() => jsonResponse(envelope({'items': <Object>[]})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(CreateOutfitPage), findsOneWidget);
        expect(_overlay, findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.byType(CreateOutfitPage), findsNothing);
        expect(find.text('Base page'), findsOneWidget);
        expect(_overlay, findsNothing);
        expect(
          find.byType(ModalBarrier),
          findsOneWidget,
          reason:
              'only the '
              "page's own, no dialog barrier left behind",
        );
      }, b.client);
    });

    testWidgets('Android back closes the overlay itself, and only it, as '
        'before', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));

        expect(_overlay, findsNothing);
        expect(find.text('Base page'), findsOneWidget);
        expect(find.text('Root'), findsNothing);

        // Ends the held load (it carries a 15s timeout timer).
        b.release(() => jsonResponse(envelope(null), status: 400));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, b.client);
    });

    testWidgets('after Android back closed the overlay, a successful load '
        'still opens Create Outfit over the page (current flow)', (
      tester,
    ) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));

        b.release(() => jsonResponse(envelope({'items': <Object>[]})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CreateOutfitPage), findsOneWidget);
        expect(_basePage, findsOneWidget);
        expect(_overlay, findsNothing);
      }, b.client);
    });
  });

  group('handleCreateTrip', () {
    _Backend backend() => _Backend(heldPath: '/trip_plans', heldMethod: 'POST');

    /// Through the create dialog (confirmed with [_tripInput]) to the held
    /// create request.
    Future<void> start(WidgetTester tester, {bool watchTrips = false}) async {
      await pumpBase(tester, watchTrips: watchTrips);
      unawaited(handleCreateTrip(baseContext, baseRef));
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(TripCreateDialog)),
      ).pop(_tripInput);
      await tester.pump();
      await tester.pump();
      expect(_overlay, findsOneWidget);
    }

    testWidgets('session expired meanwhile: the late reply leaves Session '
        'Expired up, adds no error, and leaves no overlay behind', (
      tester,
    ) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await expireSessionElsewhere(tester);

        b.release(() => jsonResponse(envelope({'id': 42})));
        await tester.pump();
        // A route removed from under another one leaves on a later frame.
        await tester.pump(const Duration(milliseconds: 500));

        expect(_sessionExpired, findsOneWidget);
        expect(_tripFailed, findsNothing);
        expect(_overlay, findsNothing);
        expect(_basePage, findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);

        await dismissSessionExpired(tester);
        expect(find.byType(LoginPage), findsOneWidget);
      }, b.client);
    });

    testWidgets('sign-out meanwhile: the late reply pops nothing off the '
        'login page', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await signOut(tester);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        drainLoginPageErrors(tester);

        b.release(() => jsonResponse(envelope({'id': 42})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        drainLoginPageErrors(tester);

        expect(find.byType(LoginPage), findsOneWidget);
        expect(_tripFailed, findsNothing);
        expect(_overlay, findsNothing);
      }, b.client);
    });

    testWidgets('created, but the session ended while its detail loaded: '
        'nothing is opened over Session Expired', (tester) async {
      final detail = Completer<http.Response>();
      final b = backend()
        ..before = (req) =>
            req.url.path.endsWith('/outfits/sync') ? detail.future : null;
      await http.runWithClient(() async {
        await start(tester);
        b.release(() => jsonResponse(envelope({'id': 42})));
        await tester.pump();
        await tester.pump();
        await expireSessionElsewhere(tester);

        detail.complete(jsonResponse(envelope(_collectionJson(42))));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(_sessionExpired, findsOneWidget);
        expect(find.byType(TripSuitcasePage), findsNothing);
        expect(find.byType(TripDetailsPage), findsNothing);
        expect(_overlay, findsNothing);
        expect(_basePage, findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
        await dismissSessionExpired(tester);
      }, b.client);
    });

    testWidgets('its own unrecoverable 401 still closes the overlay and '
        'goes to Session Expired', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        b.release(() => http.Response('{}', 401));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(_overlay, findsNothing);
        expect(_sessionExpired, findsOneWidget);
        expect(_tripFailed, findsNothing);
        await dismissSessionExpired(tester);
      }, b.client);
    });

    testWidgets('a 500 closes only the overlay and shows the error', (
      tester,
    ) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        b.release(() => jsonResponse(envelope(null), status: 500));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(_overlay, findsNothing);
        expect(_tripFailed, findsOneWidget);
        expect(_basePage, findsOneWidget);
      }, b.client);
    });

    testWidgets('an overlay already closed by a system back: the reply pops '
        'nothing else', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));
        expect(_overlay, findsNothing);

        b.release(() => jsonResponse(envelope(null), status: 500));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(_basePage, findsOneWidget);
        expect(_tripFailed, findsOneWidget);
      }, b.client);
    });

    String? topTitle(WidgetTester tester) =>
        ModalRoute.of(tester.element(find.text('Base page')))?.isCurrent == true
        ? 'Base page'
        : null;

    testWidgets('success: the trip is added to the list, the overlay closes, '
        'Suitcase opens over Trip Details, and back walks out without an '
        'overlay or stray route', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester, watchTrips: true);
        b.release(() => jsonResponse(envelope({'id': 42})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(_overlay, findsNothing);
        expect(find.byType(TripSuitcasePage), findsOneWidget);
        expect(
          find.byType(TripDetailsPage, skipOffstage: false),
          findsOneWidget,
        );
        expect(_basePage, findsOneWidget);
        final trips = ProviderScope.containerOf(
          baseContext,
        ).read(tripsProvider).value;
        expect(trips?.map((t) => (t.id, t.name)), [('42', 'Kyoto')]);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TripSuitcasePage), findsNothing);
        expect(find.byType(TripDetailsPage), findsOneWidget);
        expect(_overlay, findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TripDetailsPage), findsNothing);
        expect(topTitle(tester), 'Base page');
        expect(_overlay, findsNothing);
        expect(find.text('Root', skipOffstage: false), findsOneWidget);
      }, b.client);
    });

    testWidgets('Android back closes the overlay itself, and only it, as '
        'before', (tester) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));

        expect(_overlay, findsNothing);
        expect(topTitle(tester), 'Base page');

        // Ends the held create (it carries a timeout timer).
        b.release(() => jsonResponse(envelope(null), status: 400));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, b.client);
    });

    testWidgets('after Android back closed the overlay, a created trip still '
        'opens Trip Details and Suitcase over the page (current flow)', (
      tester,
    ) async {
      final b = backend();
      await http.runWithClient(() async {
        await start(tester);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));

        b.release(() => jsonResponse(envelope({'id': 42})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(TripSuitcasePage), findsOneWidget);
        expect(
          find.byType(TripDetailsPage, skipOffstage: false),
          findsOneWidget,
        );
        expect(_basePage, findsOneWidget);
        expect(_overlay, findsNothing);
      }, b.client);
    });
  });

  group('ModalLoadingOverlay', () {
    ModalLoadingOverlay showOverlay() =>
        ModalLoadingOverlay.show(baseContext, label: 'Loading…');

    bool baseIsTop(WidgetTester tester) =>
        ModalRoute.of(tester.element(find.text('Base page')))?.isCurrent ??
        false;

    testWidgets('close() twice closes only the overlay', (tester) async {
      await pumpBase(tester);
      final loading = showOverlay();
      await tester.pump();
      expect(_overlay, findsOneWidget);

      loading.close();
      loading.close();
      await tester.pumpAndSettle();

      expect(_overlay, findsNothing);
      expect(baseIsTop(tester), isTrue);
      expect(find.text('Root', skipOffstage: false), findsOneWidget);
    });

    testWidgets('close() again mid exit animation is a no-op', (tester) async {
      await pumpBase(tester);
      final loading = showOverlay();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // fully in

      loading.close();
      await tester.pump(const Duration(milliseconds: 10));
      expect(_overlay, findsOneWidget, reason: 'still fading out');
      loading.close();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_overlay, findsNothing);
      expect(baseIsTop(tester), isTrue);
    });

    testWidgets('covered by another dialog: close() removes only the overlay, '
        'and closing again changes nothing', (tester) async {
      await pumpBase(tester);
      final loading = showOverlay();
      await tester.pump();
      unawaited(
        showDialog<void>(
          context: baseContext,
          builder: (_) => const AlertDialog(content: Text('On top')),
        ),
      );
      // Not pumpAndSettle while the overlay is up: its dots never settle.
      await tester.pump(const Duration(milliseconds: 500));
      expect(_overlay, findsOneWidget);

      loading.close();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_overlay, findsNothing);
      expect(find.text('On top'), findsOneWidget);

      loading.close();
      await tester.pumpAndSettle();
      expect(find.text('On top'), findsOneWidget);

      Navigator.of(tester.element(find.text('On top'))).pop();
      await tester.pumpAndSettle();
      expect(baseIsTop(tester), isTrue);
      expect(_overlay, findsNothing);
    });

    testWidgets('already removed by other navigation: close() does nothing', (
      tester,
    ) async {
      await pumpBase(tester);
      final loading = showOverlay();
      await tester.pump();
      unawaited(
        Navigator.of(baseContext).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Elsewhere')),
          ),
          (_) => false,
        ),
      );
      await tester.pumpAndSettle();
      expect(_overlay, findsNothing);

      loading.close();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Elsewhere'), findsOneWidget);
    });

    testWidgets('closed by Android back: close() does nothing', (tester) async {
      await pumpBase(tester);
      final loading = showOverlay();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_overlay, findsNothing);

      loading.close();
      await tester.pumpAndSettle();

      expect(baseIsTop(tester), isTrue);
      expect(find.text('Root', skipOffstage: false), findsOneWidget);
    });
  });
}
