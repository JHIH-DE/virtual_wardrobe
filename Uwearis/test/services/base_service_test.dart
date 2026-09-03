import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
}
