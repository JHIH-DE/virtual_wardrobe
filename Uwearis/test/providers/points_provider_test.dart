import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/points_provider.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/points_service.dart';
import 'package:uwearis/core/services/trip_service.dart';
import 'package:uwearis/core/utils/analytics.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/points_fixture.dart';

/// A `GET /points` backend whose balance the test moves, as the server's
/// debits / refunds / reservations would. With [hold], each reply waits
/// until the test releases it, answering with the balance current *when the
/// request arrived* — how a real server answers.
class _PointsBackend {
  int balance = 140;
  int nextGrant = 15;
  DateTime? nextClaimAt;
  int gets = 0;
  bool hold = false;
  http.Response? failWith;
  final List<Completer<void>> held = [];

  /// Other endpoints (the charged AI calls themselves).
  http.Response Function(http.Request request)? onOther;

  late final MockClient client = MockClient((request) async {
    if (!isPointsSummaryPath(request.url.path)) {
      return onOther?.call(request) ?? http.Response('unexpected', 500);
    }
    gets++;
    final failure = failWith;
    final json = pointsSummaryJson(balance: balance, nextGrant: nextGrant);
    if (nextClaimAt != null) {
      json['next_claim_at'] = nextClaimAt!.toUtc().toIso8601String();
    }
    if (hold) {
      final gate = Completer<void>();
      held.add(gate);
      await gate.future;
    }
    return failure ?? jsonResponse(envelope(json));
  });

  void releaseAll() {
    for (final gate in held) {
      if (!gate.isCompleted) gate.complete();
    }
    held.clear();
  }
}

http.Response _apiError(int status, String code) => jsonResponse({
  'success': false,
  'message': 'backend detail',
  'data': null,
  'error_code': code,
}, status: status);

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _PointsBackend backend;

  setUp(() {
    setUpFakeAuth();
    PointsService.lastSummary = null;
    backend = _PointsBackend();
  });

  /// A container with [pointsProvider] actively listened to (as the
  /// wardrobe nav bar does), all HTTP served by [backend].
  Future<ProviderContainer> listening() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(pointsProvider, (_, _) {});
    await _settle();
    return container;
  }

  Future<T> withBackend<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => backend.client);

  int? balanceOf(ProviderContainer c) => c.read(pointsProvider).value?.balance;

  group('load and refresh', () {
    test('first load shows the balance from GET /points', () {
      return withBackend(() async {
        final container = await listening();

        expect(balanceOf(container), 140);
        expect(backend.gets, 1);
      });
    });

    test('refresh() keeps showing the balance while it reloads, then the '
        'new one', () {
      return withBackend(() async {
        final container = await listening();
        backend
          ..balance = 100
          ..hold = true;

        final refresh = container.read(pointsProvider.notifier).refresh();
        await _settle();
        final mid = container.read(pointsProvider);
        expect(mid.isLoading, isTrue);
        expect(mid.value?.balance, 140);

        backend.releaseAll();
        await refresh;
        expect(balanceOf(container), 100);
      });
    });

    test('a failed refresh() is an error that still carries the last '
        'balance', () {
      return withBackend(() async {
        final container = await listening();
        backend.failWith = _apiError(400, 'BAD_REQUEST');

        await container.read(pointsProvider.notifier).refresh();

        final state = container.read(pointsProvider);
        expect(state.hasError, isTrue);
        expect(state.value?.balance, 140);
      });
    });
  });

  group('re-sync after AI calls (balanceChanges)', () {
    test('a successful charged call: the provider re-reads the debited '
        'balance', () {
      return withBackend(() async {
        final container = await listening();

        await PointsService.charged(() async {
          backend.balance = 110; // debited server-side
          return 'ok';
        }, feature: ChargedFeature.tryOn);
        await _settle();

        expect(balanceOf(container), 110);
        expect(backend.gets, 2);
      });
    });

    test('a failed charged call the backend refunded: the re-read shows the '
        'unchanged balance — the app assumes nothing itself', () {
      return withBackend(() async {
        final container = await listening();
        backend.onOther = (_) => _apiError(500, 'INTERNAL_SERVER_ERROR');

        await expectLater(
          TripService().analyzeTrip(5),
          throwsA(isA<ApiException>()),
        );
        await _settle();

        expect(backend.gets, 2);
        expect(balanceOf(container), 140);
      });
    });

    test('a lost reply whose render is still holding its points: the '
        're-read shows the held (lower) balance', () {
      return withBackend(() async {
        final container = await listening();

        await expectLater(
          PointsService.charged<String>(() async {
            backend.balance = 110; // reserved by the still-running render
            throw TimeoutException('no reply');
          }, feature: ChargedFeature.tryOn),
          throwsA(isA<TimeoutException>()),
        );
        await _settle();

        expect(balanceOf(container), 110);
      });
    });

    test('a 402 (nothing debited): re-read, balance unchanged, and the '
        'provider stays in data', () {
      return withBackend(() async {
        final container = await listening();
        backend.onOther = (_) => _apiError(402, 'INSUFFICIENT_POINTS');

        await expectLater(
          TripService().analyzeTrip(5),
          throwsA(isA<ApiException>()),
        );
        await _settle();

        expect(backend.gets, 2);
        final state = container.read(pointsProvider);
        expect(state.hasError, isFalse);
        expect(state.value?.balance, 140);
      });
    });

    test('AI calls finishing one after another each re-sync, ending on the '
        'latest balance', () {
      return withBackend(() async {
        final container = await listening();
        for (final next in [110, 80, 50]) {
          await PointsService.charged(() async {
            backend.balance = next;
            return 'ok';
          }, feature: ChargedFeature.tryOn);
          await _settle();
        }

        expect(backend.gets, 4);
        expect(balanceOf(container), 50);
      });
    });

    test('an AI call finishing while a re-read is already in flight still ends '
        'on its debited balance', () {
      return withBackend(() async {
        final container = await listening();
        backend.hold = true;

        // Call A finishes: its re-read reaches the server at balance 110.
        backend.balance = 110;
        PointsService.notifyBalanceChanged();
        await _settle();
        expect(backend.held, hasLength(1));

        // Call B is debited and finishes while A's re-read is in flight.
        backend.balance = 80;
        PointsService.notifyBalanceChanged();
        await _settle();

        backend.hold = false;
        backend.releaseAll();
        await _settle();

        expect(balanceOf(container), 80);
      });
    });

    /// Holds the next re-read (answered with the balance current when it
    /// reached the server) and returns once it's in flight.
    Future<void> holdNextReread() async {
      backend.hold = true;
      PointsService.notifyBalanceChanged();
      await _settle();
      expect(backend.held, hasLength(1));
    }

    /// Answers held reads one at a time (a trailing read is held too),
    /// until nothing is waiting.
    Future<void> answerAll() async {
      while (backend.held.isNotEmpty) {
        backend.releaseAll();
        await _settle();
      }
      backend.hold = false;
    }

    test('many changes during one re-read coalesce into one trailing '
        're-read', () {
      return withBackend(() async {
        final container = await listening();
        backend.balance = 110;
        await holdNextReread();

        for (final next in [100, 90, 80]) {
          backend.balance = next;
          PointsService.notifyBalanceChanged();
          await _settle();
        }
        expect(backend.held, hasLength(1), reason: 'no GET per change');

        await answerAll();
        expect(backend.gets, 3, reason: 'first load + re-read + one trailing');
        expect(balanceOf(container), 80);
      });
    });

    test('a caller that joined the in-flight re-read gets the trailing '
        "result when a change lands meanwhile — announceRemainingPoints' "
        'case', () {
      return withBackend(() async {
        final container = await listening();
        backend
          ..balance = 110
          ..hold = true;
        final joined = container.read(pointsProvider.notifier).reloadPoints();
        await _settle();

        backend.balance = 80;
        PointsService.notifyBalanceChanged();
        await _settle();
        await answerAll();

        expect((await joined)?.balance, 80);
      });
    });

    test("plain concurrent callers still share one request when nothing "
        'changed meanwhile', () {
      return withBackend(() async {
        final container = await listening();
        final notifier = container.read(pointsProvider.notifier);
        backend
          ..balance = 90
          ..hold = true;
        final calls = [
          notifier.reloadPoints(),
          notifier.reloadPoints(),
          notifier.reloadPoints(),
        ];
        await _settle();
        await answerAll();

        final results = await Future.wait(calls);
        expect(backend.gets, 2);
        expect(results.map((r) => r?.balance), [90, 90, 90]);
      });
    });

    test('a failed re-read still runs the trailing one for a change that '
        'landed meanwhile', () {
      return withBackend(() async {
        final container = await listening();
        final notifier = container.read(pointsProvider.notifier);
        backend
          ..hold = true
          ..failWith = _apiError(503, 'SERVICE_UNAVAILABLE');
        final joined = notifier.reloadPoints();
        await _settle();

        backend.balance = 80;
        PointsService.notifyBalanceChanged();
        await _settle();
        // The trailing read is sent once the first answers; it succeeds.
        backend.failWith = null;
        backend.releaseAll(); // the first read, which failed on arrival
        await _settle();
        await answerAll();

        expect(backend.gets, 3);
        expect((await joined)?.balance, 80);
        expect(balanceOf(container), 80);
      });
    });

    test('a failed trailing re-read gives the caller nothing rather than '
        'the balance it knew to be outdated', () {
      return withBackend(() async {
        final container = await listening();
        final notifier = container.read(pointsProvider.notifier);
        backend
          ..balance = 110
          ..hold = true;
        final joined = notifier.reloadPoints();
        await _settle();

        backend.balance = 80;
        PointsService.notifyBalanceChanged();
        await _settle();
        // The trailing read is sent once the first answers; it fails.
        backend.failWith = _apiError(503, 'SERVICE_UNAVAILABLE');
        backend.releaseAll(); // the first read, answered 110 on arrival
        await _settle();
        await answerAll();

        expect(await joined, isNull);
        final state = container.read(pointsProvider);
        expect(state.hasError, isFalse);
        expect(state.value?.balance, 110);
      });
    });

    test('a change after the re-read finished starts a fresh one', () {
      return withBackend(() async {
        final container = await listening();
        backend.balance = 110;
        await holdNextReread();
        await answerAll();
        expect(backend.gets, 2);

        backend.balance = 80;
        PointsService.notifyBalanceChanged();
        await _settle();

        expect(backend.gets, 3);
        expect(balanceOf(container), 80);
      });
    });

    test("a change pending on the previous account's re-read doesn't run a "
        'trailing re-read after the switch', () {
      return withBackend(() async {
        final container = await listening();
        backend.balance = 999;
        await holdNextReread();
        PointsService.notifyBalanceChanged(); // marks A's re-read stale
        await _settle();

        setUpFakeAuth(accessToken: 'account-b');
        backend
          ..balance = 15
          ..hold = false;
        container.invalidate(pointsProvider);
        await _settle();
        expect(balanceOf(container), 15);
        final gets = backend.gets;

        backend.releaseAll(); // A's re-read lands
        await _settle();

        expect(backend.gets, gets, reason: 'no trailing GET for A');
        expect(balanceOf(container), 15);
      });
    });
  });

  group('reloadPoints', () {
    test('concurrent calls share one request and one result', () {
      return withBackend(() async {
        final container = await listening();
        final notifier = container.read(pointsProvider.notifier);
        backend
          ..balance = 90
          ..hold = true;

        final a = notifier.reloadPoints();
        final b = notifier.reloadPoints();
        await _settle();
        backend.releaseAll();
        final results = await Future.wait([a, b]);

        expect(backend.gets, 2, reason: 'first load + one shared reload');
        expect(results[0], same(results[1]));
        expect(results[0]?.balance, 90);
      });
    });

    test('a call after the shared one finished sends a new request', () {
      return withBackend(() async {
        final container = await listening();
        final notifier = container.read(pointsProvider.notifier);

        await notifier.reloadPoints();
        backend.balance = 60;
        final second = await notifier.reloadPoints();

        expect(backend.gets, 3);
        expect(second?.balance, 60);
      });
    });

    test('never drops to loading, and on failure returns null and keeps '
        'the balance shown', () {
      return withBackend(() async {
        final container = await listening();
        backend
          ..hold = true
          ..failWith = _apiError(503, 'SERVICE_UNAVAILABLE');

        final reload = container.read(pointsProvider.notifier).reloadPoints();
        await _settle();
        expect(container.read(pointsProvider).isLoading, isFalse);

        backend.releaseAll();
        expect(await reload, isNull);
        final state = container.read(pointsProvider);
        expect(state.hasError, isFalse);
        expect(state.value?.balance, 140);
      });
    });
  });

  group('account switch', () {
    test("invalidating (next sign-in) re-reads the new account's balance", () {
      return withBackend(() async {
        final container = await listening();
        setUpFakeAuth(accessToken: 'account-b');
        backend.balance = 15;

        container.invalidate(pointsProvider);
        await _settle();

        expect(balanceOf(container), 15);
      });
    });

    test("a re-read from the previous account that lands after the switch "
        "doesn't overwrite the new account's balance", () {
      return withBackend(() async {
        final container = await listening();
        backend
          ..balance = 999
          ..hold = true;
        final oldReload = container
            .read(pointsProvider.notifier)
            .reloadPoints();
        await _settle();

        // Sign-in as account B: the provider rebuilds and reads B's balance.
        setUpFakeAuth(accessToken: 'account-b');
        backend.balance = 15;
        container.invalidate(pointsProvider);
        await _settle();
        final gates = [...backend.held];
        backend
          ..held.clear()
          ..hold = false;
        expect(gates, hasLength(2));

        gates[1].complete(); // B's first load → 15
        await _settle();
        expect(balanceOf(container), 15);

        gates[0].complete(); // A's late re-read → 999
        await oldReload;
        await _settle();
        expect(balanceOf(container), 15);
        expect(container.read(pointsProvider).hasError, isFalse);
      });
    });

    /// Releases held GETs in [order].
    Future<void> release(List<Completer<void>> gates, List<int> order) async {
      for (final i in order) {
        gates[i].complete();
        await _settle();
      }
    }

    test('A → B → C in quick succession: neither A nor B can overwrite C, '
        'whatever order their replies land in', () {
      return withBackend(() async {
        final container = await listening();
        final notifier = container.read(pointsProvider.notifier);
        backend.hold = true;

        backend.balance = 111; // A's re-read
        final aReload = notifier.reloadPoints();
        await _settle();
        backend.balance = 222; // B's first load
        setUpFakeAuth(accessToken: 'account-b');
        container.invalidate(pointsProvider);
        await _settle();
        backend.balance = 333; // C's first load
        setUpFakeAuth(accessToken: 'account-c');
        container.invalidate(pointsProvider);
        await _settle();

        final gates = [...backend.held];
        backend
          ..held.clear()
          ..hold = false;
        expect(gates, hasLength(3));

        await release(gates, [2, 1, 0]);
        await aReload;
        expect(balanceOf(container), 333);
        expect(container.read(pointsProvider).hasError, isFalse);
      });
    });

    test('repeated invalidates while loads are in flight settle on the '
        'last one', () {
      return withBackend(() async {
        final container = await listening();
        backend.hold = true;
        for (final balance in [10, 20, 30]) {
          backend.balance = balance;
          container.invalidate(pointsProvider);
          await _settle();
        }
        final gates = [...backend.held];
        backend
          ..held.clear()
          ..hold = false;

        await release(gates, [2, 0, 1]);
        expect(balanceOf(container), 30);
      });
    });

    test("after a switch, reloadPoints doesn't join the previous account's "
        "in-flight re-read — it reads the new account's balance", () {
      return withBackend(() async {
        final container = await listening();
        final notifier = container.read(pointsProvider.notifier);
        backend
          ..balance = 999
          ..hold = true;
        final aReload = notifier.reloadPoints();
        await _settle();

        setUpFakeAuth(accessToken: 'account-b');
        backend
          ..balance = 15
          ..hold = false;
        container.invalidate(pointsProvider);
        await _settle();
        expect(balanceOf(container), 15);

        final bReload = await notifier.reloadPoints();
        expect(bReload?.balance, 15);

        backend.releaseAll();
        expect(
          await aReload,
          isNull,
          reason: "a stale caller gets nothing, not A's balance to announce",
        );
        await _settle();
        expect(balanceOf(container), 15);
      });
    });

    test("a refresh() from the previous account that lands after the switch "
        "doesn't overwrite the new account's balance", () {
      return withBackend(() async {
        final container = await listening();
        backend
          ..balance = 999
          ..hold = true;
        final aRefresh = container.read(pointsProvider.notifier).refresh();
        await _settle();

        setUpFakeAuth(accessToken: 'account-b');
        backend
          ..balance = 15
          ..hold = false;
        container.invalidate(pointsProvider);
        await _settle();
        expect(balanceOf(container), 15);

        backend.releaseAll();
        await aRefresh;
        await _settle();
        expect(balanceOf(container), 15);
        expect(container.read(pointsProvider).hasError, isFalse);
      });
    });

    test('balanceChanges after a switch reach only the new account', () {
      return withBackend(() async {
        final container = await listening();
        setUpFakeAuth(accessToken: 'account-b');
        backend.balance = 15;
        container.invalidate(pointsProvider);
        await _settle();
        final gets = backend.gets;

        backend.balance = 12;
        PointsService.notifyBalanceChanged();
        await _settle();

        expect(backend.gets, gets + 1, reason: 'one listener, not two');
        expect(balanceOf(container), 12);
      });
    });
  });

  group('next daily grant', () {
    // testWidgets for its fake clock: `tester.pump(d)` fires timers due in d.
    // Lets secure-storage reads, the request and the reply all run.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        // Not zero: an invalidated provider rebuilds only once time moves.
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    Future<ProviderContainer> startListening(WidgetTester tester) async {
      final container = ProviderContainer();
      container.listen(pointsProvider, (_, _) {});
      await settle(tester);
      return container;
    }

    testWidgets('re-reads a few seconds after the next grant time', (
      tester,
    ) async {
      await withBackend(() async {
        backend.nextClaimAt = DateTime.now().add(const Duration(seconds: 30));
        final container = await startListening(tester);
        expect(backend.gets, 1);

        await tester.pump(const Duration(seconds: 30));
        expect(backend.gets, 1, reason: 'waits past the grant itself');
        await tester.pump(const Duration(seconds: 6));
        expect(backend.gets, 2);
        container.dispose();
      });
    });

    testWidgets('no timer when no grant is coming', (tester) async {
      await withBackend(() async {
        backend
          ..nextGrant = 0
          ..nextClaimAt = DateTime.now().add(const Duration(seconds: 30));
        final container = await startListening(tester);

        await tester.pump(const Duration(minutes: 5));
        expect(backend.gets, 1);
        container.dispose();
      });
    });

    testWidgets('the timer is cancelled with the provider', (tester) async {
      await withBackend(() async {
        backend.nextClaimAt = DateTime.now().add(const Duration(seconds: 30));
        final container = await startListening(tester);

        container.dispose();
        await tester.pump(const Duration(minutes: 5));
        expect(backend.gets, 1);
      });
    });

    testWidgets(
      'a provider disposed while its first load is in flight leaves no '
      'timer behind',
      (tester) async {
        await withBackend(() async {
          backend
            ..nextClaimAt = DateTime.now().add(const Duration(seconds: 30))
            ..hold = true;
          final container = await startListening(tester);

          container.dispose(); // e.g. sign-out mid-load
          backend
            ..hold = false
            ..releaseAll();
          await tester.pump();

          await tester.pump(const Duration(minutes: 5));
          expect(backend.gets, 1);
        });
      },
    );

    testWidgets("a previous account's first load landing after the switch "
        "doesn't schedule a grant timer for the new account", (tester) async {
      await withBackend(() async {
        backend
          ..nextClaimAt = DateTime.now().add(const Duration(seconds: 30))
          ..hold = true;
        final container = await startListening(tester);

        // B has no grant coming, so B itself schedules nothing.
        backend
          ..hold = false
          ..nextGrant = 0;
        container.invalidate(pointsProvider);
        await settle(tester);
        final gets = backend.gets;

        backend.releaseAll(); // A's load, which had a grant 30s away
        await settle(tester);
        await tester.pump(const Duration(minutes: 5));

        expect(backend.gets, gets);
        container.dispose();
      });
    });

    testWidgets("a previous account's re-read landing after the switch "
        "doesn't schedule a grant timer for the new account", (tester) async {
      await withBackend(() async {
        backend.nextGrant = 0;
        final container = await startListening(tester);
        backend
          ..nextGrant = 15
          ..nextClaimAt = DateTime.now().add(const Duration(seconds: 30))
          ..hold = true;
        final aReload = container.read(pointsProvider.notifier).reloadPoints();
        await settle(tester);

        backend
          ..hold = false
          ..nextGrant = 0;
        container.invalidate(pointsProvider);
        await settle(tester);
        final gets = backend.gets;

        backend.releaseAll();
        await aReload;
        await tester.pump(const Duration(minutes: 5));

        expect(backend.gets, gets);
        container.dispose();
      });
    });

    testWidgets('a normal rebuild still schedules its own grant timer', (
      tester,
    ) async {
      await withBackend(() async {
        backend.nextGrant = 0;
        final container = await startListening(tester);
        expect(container.read(pointsProvider).hasValue, isTrue);
        backend
          ..nextGrant = 15
          ..nextClaimAt = DateTime.now().add(const Duration(seconds: 30));
        container.invalidate(pointsProvider);
        await settle(tester);
        final gets = backend.gets;

        await tester.pump(const Duration(seconds: 36));
        expect(backend.gets, gets + 1);
        container.dispose();
      });
    });
  });
}
