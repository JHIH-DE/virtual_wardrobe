import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uwearis/core/providers/retry_policy.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/garment_service.dart'
    show ClosetAnalysisException;

/// `build()` delegates to [attemptFn]; [attempts] counts failed runs too.
class _FlakyNotifier extends AsyncNotifier<int> {
  _FlakyNotifier(this.attemptFn);
  final int Function(int attempt) attemptFn;
  int attempts = 0;

  @override
  Future<int> build() async {
    final thisAttempt = attempts;
    attempts++;
    return attemptFn(thisAttempt);
  }
}

final _testProvider = AsyncNotifierProvider<_FlakyNotifier, int>(
  () => _FlakyNotifier((_) => throw UnimplementedError('override me')),
  retry: appRetryPolicy,
);

/// Keeps an active `listen` open: Riverpod only runs a scheduled retry
/// while the provider has a subscriber.
({ProviderContainer container, _FlakyNotifier notifier}) _wireUp(
  int Function(int attempt) attemptFn,
) {
  late _FlakyNotifier notifier;
  final container = ProviderContainer(
    overrides: [
      _testProvider.overrideWith(() => notifier = _FlakyNotifier(attemptFn)),
    ],
  );
  container.listen(_testProvider, (_, _) {});
  return (container: container, notifier: notifier);
}

void main() {
  group('appRetryPolicy — direct unit tests', () {
    test('AuthExpiredException: 0 retry, regardless of retryCount', () {
      expect(appRetryPolicy(0, AuthExpiredException()), isNull);
      expect(appRetryPolicy(1, AuthExpiredException()), isNull);
    });

    test('ApiException 400/404/422: 0 retry', () {
      expect(
        appRetryPolicy(0, const ApiException(statusCode: 400, message: 'x')),
        isNull,
      );
      expect(
        appRetryPolicy(0, const ApiException(statusCode: 404, message: 'x')),
        isNull,
      );
      expect(
        appRetryPolicy(0, const ApiException(statusCode: 422, message: 'x')),
        isNull,
      );
    });

    test('ApiException 500: retries, capped at 3 attempts', () {
      const error = ApiException(statusCode: 500, message: 'x');
      expect(appRetryPolicy(0, error), isNotNull);
      expect(appRetryPolicy(1, error), isNotNull);
      expect(appRetryPolicy(2, error), isNotNull);
      // 3 retries is the cap.
      expect(appRetryPolicy(3, error), isNull);
    });

    test('other 5xx (502, 503) also retry — not just 500', () {
      expect(
        appRetryPolicy(0, const ApiException(statusCode: 502, message: 'x')),
        isNotNull,
      );
      expect(
        appRetryPolicy(0, const ApiException(statusCode: 503, message: 'x')),
        isNotNull,
      );
    });

    test('TimeoutException: retries', () {
      expect(appRetryPolicy(0, TimeoutException('slow')), isNotNull);
    });

    test('SocketException: retries', () {
      expect(appRetryPolicy(0, const SocketException('no route')), isNotNull);
    });

    test('http.ClientException: retries', () {
      expect(
        appRetryPolicy(0, http.ClientException('connection reset')),
        isNotNull,
      );
    });

    test('an unknown/unclassified Exception: 0 retry', () {
      expect(appRetryPolicy(0, Exception('something odd')), isNull);
    });

    test('a known business exception (ClosetAnalysisException): 0 retry', () {
      expect(
        appRetryPolicy(0, const ClosetAnalysisException('SOME_CODE', 'x')),
        isNull,
      );
    });

    test('a FormatException: 0 retry', () {
      expect(appRetryPolicy(0, const FormatException('bad json')), isNull);
    });

    test('backoff is short and increasing, never accumulating to tens of '
        'seconds', () {
      const error = ApiException(statusCode: 500, message: 'x');
      final d0 = appRetryPolicy(0, error)!;
      final d1 = appRetryPolicy(1, error)!;
      final d2 = appRetryPolicy(2, error)!;
      expect(d0, lessThan(d1));
      expect(d1, lessThan(d2));
      final total = d0 + d1 + d2;
      expect(total, lessThan(const Duration(seconds: 5)));
    });
  });

  group('appRetryPolicy wired into a real AsyncNotifierProvider', () {
    test(
      'eventually succeeds within the retry budget settles as AsyncData',
      () async {
        final w = _wireUp((attempt) {
          if (attempt < 2) {
            throw const ApiException(statusCode: 500, message: 'boom');
          }
          return 42;
        });
        addTearDown(w.container.dispose);

        final value = await w.container.read(_testProvider.future);
        expect(value, 42);
        expect(w.container.read(_testProvider), const AsyncData<int>(42));
        expect(w.notifier.attempts, 3);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test('a persistent transient error settles into AsyncError within a few '
        'seconds, not tens of seconds', () async {
      final w = _wireUp(
        (_) => throw const ApiException(statusCode: 500, message: 'boom'),
      );
      addTearDown(w.container.dispose);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        w.container.read(_testProvider.future),
        throwsA(isA<ApiException>()),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 8)));
      expect(w.notifier.attempts, 4);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('AuthExpiredException makes provider.future reject immediately — no '
        'retry wait at all', () async {
      final w = _wireUp((_) => throw AuthExpiredException());
      addTearDown(w.container.dispose);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        w.container.read(_testProvider.future),
        throwsA(isA<AuthExpiredException>()),
      );
      stopwatch.stop();

      // No retry, so no backoff delay.
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(w.notifier.attempts, 1);
    });

    test('a 4xx ApiException also rejects immediately, no retry', () async {
      final w = _wireUp(
        (_) => throw const ApiException(statusCode: 404, message: 'not found'),
      );
      addTearDown(w.container.dispose);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        w.container.read(_testProvider.future),
        throwsA(isA<ApiException>()),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(w.notifier.attempts, 1);
    });
  });
}
