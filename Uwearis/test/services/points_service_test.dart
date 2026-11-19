import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/base_service.dart';
import 'package:uwearis/core/services/points_service.dart';
import 'package:uwearis/core/services/trip_service.dart';
import 'package:uwearis/core/utils/analytics.dart';
import 'package:uwearis/core/utils/api_error_text.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/points_fixture.dart';

/// Collects [PointsService.balanceChanges] events for one test.
class _BalanceEvents {
  _BalanceEvents() {
    _sub = PointsService.balanceChanges.listen((_) => count++);
  }

  late final StreamSubscription<void> _sub;
  int count = 0;

  Future<void> close() => _sub.cancel();
}

/// Lets a broadcast (async) event reach its listeners.
Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

http.Response _apiError(int status, String code) => jsonResponse({
  'success': false,
  'message': 'backend detail',
  'data': null,
  'error_code': code,
}, status: status);

Matcher get _staleSession => throwsA(isA<SessionChangedException>());

void main() {
  late _BalanceEvents events;

  setUp(() {
    setUpFakeAuth();
    PointsService.lastSummary = null;
    events = _BalanceEvents();
    addTearDown(events.close);
  });

  group('getPoints', () {
    test('parses the summary and remembers it for copy without a provider', () {
      return http.runWithClient(
        () async {
          final summary = await PointsService().getPoints();

          expect(summary.balance, 140);
          expect(summary.costs['try_on'], 30);
          expect(PointsService.lastSummary, same(summary));
        },
        () => MockClient(
          (_) async => jsonResponse(envelope(pointsSummaryJson())),
        ),
      );
    });

    test("a failed read doesn't replace the remembered summary", () {
      return http.runWithClient(
        () async {
          final before = PointsService.lastSummary = await PointsService()
              .getPoints();
          // A 4xx: getPoints retries a timeout, not an error status.
          await expectLater(
            http.runWithClient(
              () => PointsService().getPoints(),
              () => MockClient((_) async => _apiError(400, 'BAD_REQUEST')),
            ),
            throwsA(isA<ApiException>()),
          );
          expect(PointsService.lastSummary, same(before));
        },
        () => MockClient(
          (_) async => jsonResponse(envelope(pointsSummaryJson())),
        ),
      );
    });
  });

  group('charged', () {
    test('success: the balance listeners are told once, the result passes '
        'through', () async {
      final result = await PointsService.charged(
        () async => 'rendered',
        feature: ChargedFeature.tryOn,
      );
      await _settle();

      expect(result, 'rendered');
      expect(events.count, 1);
    });

    test('a 402 reply (nothing was debited) is returned as-is, and the '
        'balance is still re-read', () async {
      final res = await PointsService.charged(
        () async => _apiError(402, insufficientPointsErrorCode),
        feature: ChargedFeature.tryOn,
      );
      await _settle();

      expect(res.statusCode, 402);
      expect(events.count, 1);
    });

    test('a thrown failure (debited then refunded, or still held) is '
        'rethrown, and the balance is still re-read', () async {
      await expectLater(
        PointsService.charged<http.Response>(
          () async => throw TimeoutException('lost reply'),
          feature: ChargedFeature.tryOn,
        ),
        throwsA(isA<TimeoutException>()),
      );
      await _settle();

      expect(events.count, 1);
    });

    test('an unrecoverable 401 is rethrown unchanged', () async {
      await expectLater(
        PointsService.charged<http.Response>(
          () async => throw AuthExpiredException(),
          feature: ChargedFeature.tripAnalyze,
        ),
        throwsA(isA<AuthExpiredException>()),
      );
      await _settle();

      expect(events.count, 1);
    });

    test('concurrent charged calls each notify once', () async {
      final a = Completer<String>();
      final b = Completer<String>();
      final both = Future.wait([
        PointsService.charged(() => a.future, feature: ChargedFeature.tryOn),
        PointsService.charged(
          () => b.future,
          feature: ChargedFeature.closetAnalysis,
        ),
      ]);
      await _settle();
      expect(events.count, 0, reason: 'nothing finished yet');

      b.complete('b');
      await _settle();
      expect(events.count, 1);

      a.complete('a');
      await both;
      await _settle();
      expect(events.count, 2);
    });
  });

  group('a real charged endpoint (Trip packing analysis)', () {
    test('402 INSUFFICIENT_POINTS surfaces as that code and still triggers '
        'a balance re-read', () {
      return http.runWithClient(
        () async {
          Object? error;
          try {
            await TripService().analyzeTrip(5);
          } catch (e) {
            error = e;
          }
          await _settle();

          expect(isInsufficientPoints(error!), isTrue);
          expect(events.count, 1);
        },
        () => MockClient(
          (_) async => _apiError(402, insufficientPointsErrorCode),
        ),
      );
    });

    test('a 5xx (the backend refunds it) still triggers a balance re-read', () {
      return http.runWithClient(
        () async {
          await expectLater(
            TripService().analyzeTrip(5),
            throwsA(isA<ApiException>()),
          );
          await _settle();

          expect(events.count, 1);
        },
        () => MockClient((_) async => _apiError(500, 'INTERNAL_SERVER_ERROR')),
      );
    });
  });

  group('sign-out', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('clearSignedInSession forgets the remembered summary', () {
      return http.runWithClient(
        () async {
          await PointsService().getPoints();
          expect(PointsService.lastSummary, isNotNull);

          await clearSignedInSession();

          expect(PointsService.lastSummary, isNull);
        },
        () => MockClient(
          (_) async => jsonResponse(envelope(pointsSummaryJson())),
        ),
      );
    });

    test("a read that started before sign-out doesn't bring the previous "
        "account's summary back", () async {
      final reply = Completer<http.Response>();
      final read = http.runWithClient(
        () => PointsService().getPoints(),
        () => MockClient((_) => reply.future),
      );
      await _settle();

      await clearSignedInSession();
      reply.complete(
        jsonResponse(envelope(pointsSummaryJson(balance: 999, nextGrant: 75))),
      );
      await expectLater(read, _staleSession);

      expect(PointsService.lastSummary, isNull);
    });

    /// One `getPoints()` whose reply the test releases; the returned
    /// completer answers with [balance].
    ({Future<void> read, void Function() answer}) heldRead(int balance) {
      final gate = Completer<void>();
      final read = http.runWithClient(
        () => PointsService().getPoints(),
        () => MockClient((_) async {
          await gate.future;
          return jsonResponse(envelope(pointsSummaryJson(balance: balance)));
        }),
      );
      return (read: read, answer: gate.complete);
    }

    test("a previous account's late read doesn't overwrite the next "
        "account's own summary", () async {
      final a = heldRead(999);
      await _settle();
      await clearSignedInSession(); // A signs out; B signs in below
      setUpFakeAuth(accessToken: 'account-b');

      final b = heldRead(15);
      await _settle();
      b.answer();
      await b.read;
      expect(PointsService.lastSummary?.balance, 15);

      a.answer();
      await expectLater(a.read, _staleSession);
      expect(PointsService.lastSummary?.balance, 15);
    });

    test('A → B → C in quick succession: whatever order the replies land '
        "in, only C's is kept", () async {
      final a = heldRead(111);
      await _settle();
      await clearSignedInSession();
      setUpFakeAuth(accessToken: 'account-b');
      final b = heldRead(222);
      await _settle();
      await clearSignedInSession();
      setUpFakeAuth(accessToken: 'account-c');
      final c = heldRead(333);
      await _settle();

      c.answer();
      await c.read;
      b.answer();
      await expectLater(b.read, _staleSession);
      a.answer();
      await expectLater(a.read, _staleSession);

      expect(PointsService.lastSummary?.balance, 333);
    });

    test("a stale read's reply is not handed to its caller either — "
        'withAuth discards a reply that outlived its session', () async {
      final a = heldRead(999);
      await _settle();
      await clearSignedInSession();
      a.answer();

      await expectLater(a.read, _staleSession);
      expect(PointsService.lastSummary, isNull);
    });

    test(
      'within one session, the later read wins even if it answers first',
      () async {
        final older = heldRead(140);
        await _settle();
        final newer = heldRead(110);
        await _settle();

        newer.answer();
        await newer.read;
        older.answer();
        await older.read;

        expect(PointsService.lastSummary?.balance, 110);
      },
    );

    test('within one session, reads still update the cache in order', () {
      return http
          .runWithClient(
            () async {
              await PointsService().getPoints();
              expect(PointsService.lastSummary?.balance, 140);
            },
            () => MockClient(
              (_) async => jsonResponse(envelope(pointsSummaryJson())),
            ),
          )
          .then(
            (_) => http.runWithClient(
              () async {
                await PointsService().getPoints();
                expect(PointsService.lastSummary?.balance, 90);
              },
              () => MockClient(
                (_) async =>
                    jsonResponse(envelope(pointsSummaryJson(balance: 90))),
              ),
            ),
          );
    });
  });
}
