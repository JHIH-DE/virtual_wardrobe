import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/base_service.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

/// Minimal concrete host for the [BaseService] mixin so `withAuth` can be
/// exercised in isolation.
class _TestService with BaseService {}

/// A refresh-endpoint response carrying a fresh token pair.
http.Response _refreshOk() => jsonResponse(
  envelope({'access_token': 'new-access', 'refresh_token': 'new-refresh'}),
);

void main() {
  setUp(setUpFakeAuth);

  group('withAuth', () {
    test('passes a non-401 response straight through, no refresh', () async {
      final tokens = <String>[];
      Future<http.Response> request(String token) async {
        tokens.add(token);
        return http.Response('body', 200);
      }

      var refreshHits = 0;
      final res = await http.runWithClient(
        () => _TestService().withAuth(request),
        () => MockClient((_) async {
          refreshHits++;
          return _refreshOk();
        }),
      );

      expect(res.statusCode, 200);
      expect(tokens, ['fake-access-token']);
      expect(refreshHits, 0);
    });

    test('on 401, refreshes and retries the original request once with the '
        'new access token', () async {
      final tokens = <String>[];
      Future<http.Response> request(String token) async {
        tokens.add(token);
        return http.Response('', tokens.length == 1 ? 401 : 200);
      }

      final res = await http.runWithClient(
        () => _TestService().withAuth(request),
        () => MockClient((_) async => _refreshOk()),
      );

      expect(res.statusCode, 200);
      expect(tokens, ['fake-access-token', 'new-access']);
    });

    test('a retry that still 401s is returned as-is for the caller to '
        'handle (not thrown here)', () async {
      final tokens = <String>[];
      Future<http.Response> request(String token) async {
        tokens.add(token);
        return http.Response('', 401);
      }

      final res = await http.runWithClient(
        () => _TestService().withAuth(request),
        () => MockClient((_) async => _refreshOk()),
      );

      expect(res.statusCode, 401);
      expect(tokens.length, 2);
    });

    test('no stored refresh token throws AuthExpiredException without '
        'calling refresh or retrying', () async {
      // Only an access token on hand — AuthStorage.getRefreshToken() is null.
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'fake-access-token',
      });

      final tokens = <String>[];
      Future<http.Response> request(String token) async {
        tokens.add(token);
        return http.Response('', 401);
      }

      var refreshHits = 0;
      await expectLater(
        http.runWithClient(
          () => _TestService().withAuth(request),
          () => MockClient((_) async {
            refreshHits++;
            return _refreshOk();
          }),
        ),
        throwsA(isA<AuthExpiredException>()),
      );
      expect(tokens.length, 1);
      expect(refreshHits, 0);
    });

    test(
      'two concurrent 401s share a single refresh call — a losing racer '
      'must not clear tokens the winner just saved',
      () async {
        var refreshHits = 0;
        Future<http.Response> makeCall() {
          var calls = 0;
          Future<http.Response> request(String token) async {
            calls++;
            return http.Response('', calls == 1 ? 401 : 200);
          }

          return _TestService().withAuth(request);
        }

        final results = await http.runWithClient(
          () => Future.wait([makeCall(), makeCall()]),
          () => MockClient((_) async {
            refreshHits++;
            return _refreshOk();
          }),
        );

        expect(results.map((r) => r.statusCode), [200, 200]);
        expect(refreshHits, 1);
      },
    );

    test('a non-200 from the refresh endpoint throws AuthExpiredException '
        'and does not retry', () async {
      final tokens = <String>[];
      Future<http.Response> request(String token) async {
        tokens.add(token);
        return http.Response('', 401);
      }

      await expectLater(
        http.runWithClient(
          () => _TestService().withAuth(request),
          () => MockClient((_) async => http.Response('', 500)),
        ),
        throwsA(isA<AuthExpiredException>()),
      );
      expect(tokens.length, 1);
    });

    // The refresh POST is wrapped in `.timeout(const Duration(seconds: 15))`.
    // Verifying the literal 15s window would need real elapsed time or
    // `fake_async` (only a transitive dependency here — not added). These
    // tests instead pin the behaviour that matters: whatever `.timeout()`
    // raises (a TimeoutException) must travel straight up, never be
    // swallowed or rewritten as AuthExpiredException, and must not trigger
    // a retry of the original request.
    test('a TimeoutException from the refresh call propagates unchanged and '
        'does not retry', () async {
      final tokens = <String>[];
      Future<http.Response> request(String token) async {
        tokens.add(token);
        return http.Response('', 401);
      }

      await expectLater(
        http.runWithClient(
          () => _TestService().withAuth(request),
          () => MockClient((_) async {
            throw TimeoutException('simulated slow refresh');
          }),
        ),
        throwsA(
          allOf(isA<TimeoutException>(), isNot(isA<AuthExpiredException>())),
        ),
      );
      expect(tokens.length, 1);
    });

    test('any other transport error from the refresh call propagates '
        'unchanged and does not retry', () async {
      final tokens = <String>[];
      Future<http.Response> request(String token) async {
        tokens.add(token);
        return http.Response('', 401);
      }

      await expectLater(
        http.runWithClient(
          () => _TestService().withAuth(request),
          () => MockClient((_) async {
            throw http.ClientException('connection reset');
          }),
        ),
        throwsA(
          allOf(
            isA<http.ClientException>(),
            isNot(isA<AuthExpiredException>()),
          ),
        ),
      );
      expect(tokens.length, 1);
    });
  });

  group('decodeMap', () {
    test('a non-2xx envelope response throws ApiException carrying the '
        'status, error_code and message — never the raw body', () {
      final res = http.Response(
        jsonEncode({
          'success': false,
          'message': 'That garment could not be found.',
          'data': null,
          'error_code': 'GARMENT_NOT_FOUND',
        }),
        404,
      );

      expect(
        () => _TestService().decodeMap(res, op: 'getGarment'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.errorCode, 'errorCode', 'GARMENT_NOT_FOUND')
              .having((e) => e.message, 'message', 'That garment could not be found.')
              .having(
                (e) => e.toString(),
                'toString()',
                isNot(contains('That garment could not be found.')),
              ),
        ),
      );
    });

    test('a non-2xx response with a non-JSON body falls back to a '
        'generic ApiException instead of throwing a parsing error', () {
      final res = http.Response('<html>502 Bad Gateway</html>', 502);

      expect(
        () => _TestService().decodeMap(res, op: 'getGarment'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.errorCode, 'errorCode', null)
              .having(
                (e) => e.toString(),
                'toString()',
                isNot(contains('Bad Gateway')),
              ),
        ),
      );
    });

    test('a non-2xx response whose JSON body has no error_code/message '
        'still produces a safe, generic ApiException', () {
      final res = http.Response(jsonEncode({'detail': 'nope'}), 400);

      expect(
        () => _TestService().decodeMap(res, op: 'getGarment'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.errorCode, 'errorCode', null),
        ),
      );
    });

    test('a 2xx response whose body is not valid JSON throws ApiException, '
        'not a raw FormatException', () {
      final res = http.Response('not json', 200);

      expect(
        () => _TestService().decodeMap(res, op: 'getGarment'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200)),
      );
    });

    test('a 2xx response whose JSON body is not an object throws '
        'ApiException', () {
      final res = http.Response(jsonEncode([1, 2, 3]), 200);

      expect(
        () => _TestService().decodeMap(res, op: 'getGarment'),
        throwsA(isA<ApiException>()),
      );
    });

    test('a 401 still throws AuthExpiredException, not ApiException', () {
      final res = http.Response(jsonEncode(envelope(null)), 401);

      expect(
        () => _TestService().decodeMap(res, op: 'getGarment'),
        throwsA(isA<AuthExpiredException>()),
      );
    });

    test('a valid 2xx envelope decodes normally', () {
      final res = http.Response(jsonEncode(envelope({'id': 1})), 200);
      final decoded = _TestService().decodeMap(res, op: 'getGarment');
      expect(decoded['data'], {'id': 1});
    });
  });

  group('retryOnTimeout', () {
    test('retries once after a TimeoutException and returns the retry', () async {
      var attempts = 0;
      Future<http.Response> request(String token) async {
        attempts++;
        if (attempts == 1) throw TimeoutException('cold start');
        return http.Response('body', 200);
      }

      final res = await http.runWithClient(
        () => _TestService().withAuth(request, retryOnTimeout: true),
        () => MockClient((_) async => _refreshOk()),
      );

      expect(res.statusCode, 200);
      expect(attempts, 2);
    });

    test('a second TimeoutException propagates', () async {
      var attempts = 0;
      Future<http.Response> request(String token) async {
        attempts++;
        throw TimeoutException('still cold');
      }

      await expectLater(
        http.runWithClient(
          () => _TestService().withAuth(request, retryOnTimeout: true),
          () => MockClient((_) async => _refreshOk()),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(attempts, 2);
    });

    test('without retryOnTimeout, a TimeoutException is not retried', () async {
      var attempts = 0;
      Future<http.Response> request(String token) async {
        attempts++;
        throw TimeoutException('slow');
      }

      await expectLater(
        http.runWithClient(
          () => _TestService().withAuth(request),
          () => MockClient((_) async => _refreshOk()),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(attempts, 1);
    });
  });
}
