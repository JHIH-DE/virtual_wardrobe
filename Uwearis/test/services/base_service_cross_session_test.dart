import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// Transitive via flutter_secure_storage; only its platform setter is used.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/services/base_service.dart';

import '../helpers/mock_http.dart';

class _TestService with BaseService {}

/// Secure storage whose writes of the previous account's refreshed tokens
/// ('…-A2') are slow, so they'd land after a sign-out's deletes and the next
/// sign-in's writes unless AuthStorage orders them.
class _SlowRefreshWriteStorage extends TestFlutterSecureStoragePlatform {
  _SlowRefreshWriteStorage(super.data);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    await Future<void>.delayed(
      Duration(milliseconds: value.endsWith('-A2') ? 30 : 5),
    );
    return super.write(key: key, value: value, options: options);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return super.delete(key: key, options: options);
  }
}

final _api = Uri.parse('https://api.test/api/v1/thing/7');

/// One request the fake backend saw.
class _Seen {
  _Seen(this.method, this.path, this.authorization, this.body);
  final String method;
  final String path;
  final String? authorization;
  final String body;
}

/// A backend whose answers the test releases one at a time, so the order of
/// "A's request answered" vs. "B signed in" is under the test's control.
class _Backend {
  final seen = <_Seen>[];

  /// The refresh tokens `/auth/refresh` was called with.
  List<String> get refreshedWith => [
    for (final s in seen)
      if (s.path.endsWith('/auth/refresh'))
        (jsonDecode(s.body) as Map)['refresh_token'] as String,
  ];

  /// The `Authorization` headers the API endpoint was called with.
  List<String?> get apiAuthorizations => [
    for (final s in seen)
      if (!s.path.endsWith('/auth/refresh')) s.authorization,
  ];

  /// Answers to API calls, in order; each waits for its gate.
  final apiAnswers = <({Completer<void> gate, int status})>[];

  /// Answers to `/auth/refresh`, in order.
  final refreshAnswers = <({Completer<void> gate, http.Response res})>[];

  final _apiCalled = StreamController<void>.broadcast();
  final _refreshCalled = StreamController<void>.broadcast();
  Future<void> get nextApiCall => _apiCalled.stream.first;
  Future<void> get nextRefreshCall => _refreshCalled.stream.first;

  int _api = 0;
  int _refresh = 0;

  MockClient client() => MockClient((req) async {
    seen.add(
      _Seen(req.method, req.url.path, req.headers['Authorization'], req.body),
    );
    if (req.url.path.endsWith('/auth/refresh')) {
      final answer = refreshAnswers[_refresh++];
      _refreshCalled.add(null);
      await answer.gate.future;
      return answer.res;
    }
    final answer = apiAnswers[_api++];
    _apiCalled.add(null);
    await answer.gate.future;
    return http.Response('{}', answer.status);
  });
}

({Completer<void> gate, int status}) _api401({bool open = false}) {
  final gate = Completer<void>();
  if (open) gate.complete();
  return (gate: gate, status: 401);
}

({Completer<void> gate, int status}) _api200() =>
    (gate: Completer<void>()..complete(), status: 200);

({Completer<void> gate, http.Response res}) _refreshTo(
  String account, {
  bool open = true,
}) {
  final gate = Completer<void>();
  if (open) gate.complete();
  return (
    gate: gate,
    res: jsonResponse(
      envelope({
        'access_token': 'access-$account',
        'refresh_token': 'refresh-$account',
      }),
    ),
  );
}

/// What `LoginPage` stores after a provider sign-in.
Future<void> _signIn(String account) => AuthStorage.startSession(
  accessToken: 'access-$account',
  refreshToken: 'refresh-$account',
);

/// What the logout paths do to tokens (`clearSignedInSession` →
/// `AuthStorage.clear`).
Future<void> _signOut() => AuthStorage.clear();

/// A's request — [method] with A's payload.
Future<http.Response> Function(String token) _requestAs(String method) =>
    (token) {
      final headers = {'Authorization': 'Bearer $token'};
      const body = '{"payload":"from-A"}';
      return switch (method) {
        'GET' => http.get(_api, headers: headers),
        'POST' => http.post(_api, headers: headers, body: body),
        'PATCH' => http.patch(_api, headers: headers, body: body),
        'DELETE' => http.delete(_api, headers: headers),
        _ => throw ArgumentError(method),
      };
    };

Matcher get _sessionChanged => throwsA(isA<SessionChangedException>());

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-A',
      'refresh_token': 'refresh-A',
    });
  });

  group('A request still in flight when the account changes', () {
    for (final method in ['GET', 'POST', 'PATCH', 'DELETE']) {
      test('$method: answered 401 after A signed out and B signed in — not '
          "refreshed with B's token, not replayed as B", () async {
        final backend = _Backend()
          ..apiAnswers.addAll([_api401(), _api200()])
          ..refreshAnswers.add(_refreshTo('B2'));

        await http.runWithClient(() async {
          final call = _TestService().withAuth(_requestAs(method));
          await backend.nextApiCall;
          await _signOut();
          await _signIn('B');
          backend.apiAnswers.first.gate.complete();
          await expectLater(call, _sessionChanged);
        }, backend.client);

        expect(backend.refreshedWith, isEmpty);
        expect(backend.apiAuthorizations, ['Bearer access-A']);
        expect(await AuthStorage.getAccessToken(), 'access-B');
        expect(await AuthStorage.getRefreshToken(), 'refresh-B');
      });
    }

    test('A → B → C: answered 401 after C signed in — not refreshed with '
        "C's token, not replayed as C", () async {
      final backend = _Backend()
        ..apiAnswers.addAll([_api401(), _api200()])
        ..refreshAnswers.add(_refreshTo('C2'));

      await http.runWithClient(() async {
        final call = _TestService().withAuth(_requestAs('POST'));
        await backend.nextApiCall;
        await _signOut();
        await _signIn('B');
        await _signOut();
        await _signIn('C');
        backend.apiAnswers.first.gate.complete();
        await expectLater(call, _sessionChanged);
      }, backend.client);

      expect(backend.refreshedWith, isEmpty);
      expect(backend.apiAuthorizations, ['Bearer access-A']);
      expect(await AuthStorage.getAccessToken(), 'access-C');
      expect(await AuthStorage.getRefreshToken(), 'refresh-C');
    });

    test('A → B → A: a request from the first A session is still stale in '
        'the second one (no ABA)', () async {
      final backend = _Backend()
        ..apiAnswers.add((gate: Completer<void>(), status: 200));

      await http.runWithClient(() async {
        final call = _TestService().withAuth(_requestAs('GET'));
        await backend.nextApiCall;
        await _signOut();
        await _signIn('B');
        await _signOut();
        await _signIn('A');
        backend.apiAnswers.first.gate.complete();
        await expectLater(call, _sessionChanged);
      }, backend.client);
    });

    test('a 200 that arrives after B signed in is not handed back as B\'s '
        'data', () async {
      final backend = _Backend()
        ..apiAnswers.add((gate: Completer<void>(), status: 200));

      await http.runWithClient(() async {
        final call = _TestService().withAuth(_requestAs('GET'));
        await backend.nextApiCall;
        await _signOut();
        await _signIn('B');
        backend.apiAnswers.first.gate.complete();
        await expectLater(call, _sessionChanged);
      }, backend.client);

      expect(await AuthStorage.getAccessToken(), 'access-B');
    });

    test("a timed-out read isn't resent (retryOnTimeout) once B has signed "
        'in', () async {
      final backend = _Backend()..apiAnswers.add(_api200());
      var sends = 0;

      await http.runWithClient(() async {
        Future<http.Response> request(String token) async {
          sends++;
          // The first send times out while the user switches accounts.
          await _signOut();
          await _signIn('B');
          throw TimeoutException('first send');
        }

        await expectLater(
          _TestService().withAuth(request, retryOnTimeout: true),
          _sessionChanged,
        );
      }, backend.client);

      expect(sends, 1);
      expect(backend.seen, isEmpty);
    });

    test('a timed-out read whose session ends during the 1s pause before '
        'its resend is not resent', () async {
      final backend = _Backend()..apiAnswers.add(_api200());
      var sends = 0;

      await http.runWithClient(() async {
        Future<http.Response> request(String token) async {
          if (sends++ == 0) throw TimeoutException('first send');
          return http.get(_api, headers: {'Authorization': 'Bearer $token'});
        }

        final call = _TestService().withAuth(request, retryOnTimeout: true);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _signOut();
        await _signIn('B');
        await expectLater(call, _sessionChanged);
      }, backend.client);

      expect(sends, 1);
      expect(backend.seen, isEmpty);
    });

    test('a 401 that arrives after A signed out (before anyone signs in) '
        'neither refreshes nor retries', () async {
      final backend = _Backend()..apiAnswers.add(_api401());

      await http.runWithClient(() async {
        final call = _TestService().withAuth(_requestAs('POST'));
        await backend.nextApiCall;
        await _signOut();
        backend.apiAnswers.first.gate.complete();
        await expectLater(call, _sessionChanged);
      }, backend.client);

      expect(backend.refreshedWith, isEmpty);
      expect(backend.apiAuthorizations, ['Bearer access-A']);
    });

    test("a request that starts after B signed in is B's", () async {
      final backend = _Backend()..apiAnswers.add(_api200());
      await _signOut();
      await _signIn('B');

      final res = await http.runWithClient(
        () => _TestService().withAuth(_requestAs('GET')),
        backend.client,
      );

      expect(res.statusCode, 200);
      expect(backend.apiAuthorizations, ['Bearer access-B']);
    });
  });

  group("A's refresh still in flight when the account changes", () {
    test("lands after A signed out and B signed in — B's stored tokens are "
        'kept, and A\'s request is not retried', () async {
      final backend = _Backend()
        ..apiAnswers.addAll([_api401(open: true), _api200()])
        ..refreshAnswers.add(_refreshTo('A2', open: false));

      await http.runWithClient(() async {
        final call = _TestService().withAuth(_requestAs('GET'));
        await backend.nextRefreshCall;
        await _signOut();
        await _signIn('B');
        backend.refreshAnswers.first.gate.complete();
        await expectLater(call, _sessionChanged);
      }, backend.client);

      expect(backend.refreshedWith, ['refresh-A']);
      expect(backend.apiAuthorizations, ['Bearer access-A']);
      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
    });

    test('lands after A signed out (nobody signed in yet) — A is not signed '
        'back in', () async {
      final backend = _Backend()
        ..apiAnswers.addAll([_api401(open: true), _api200()])
        ..refreshAnswers.add(_refreshTo('A2', open: false));

      await http.runWithClient(() async {
        final call = _TestService().withAuth(_requestAs('GET'));
        await backend.nextRefreshCall;
        await _signOut();
        backend.refreshAnswers.first.gate.complete();
        await expectLater(call, _sessionChanged);
      }, backend.client);

      expect(backend.refreshedWith, ['refresh-A']);
      expect(await AuthStorage.getAccessToken(), isNull);
      expect(await AuthStorage.getRefreshToken(), isNull);
    });

    test("rejected after B signed in (A's logout revoked it) — B's tokens "
        'are kept', () async {
      final gate = Completer<void>();
      final backend = _Backend()
        ..apiAnswers.add(_api401(open: true))
        ..refreshAnswers.add((
          gate: gate,
          res: http.Response(
            jsonEncode({
              'success': false,
              'message': 'revoked',
              'data': null,
              'error_code': 'REFRESH_TOKEN_REVOKED',
            }),
            401,
          ),
        ));

      await http.runWithClient(() async {
        final call = _TestService().withAuth(_requestAs('GET'));
        await backend.nextRefreshCall;
        await _signOut();
        await _signIn('B');
        gate.complete();
        await expectLater(call, _sessionChanged);
      }, backend.client);

      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
    });

    test("B's 401s don't join A's refresh: B refreshes with its own token, "
        "once, and A's refresh landing later neither touches B's tokens nor "
        "ends B's single-flight", () async {
      final backend = _Backend()
        ..apiAnswers.addAll([
          _api401(open: true), // A's request
          _api401(open: true), // B's first request
          _api401(open: true), // B's second request
          _api200(), // B's retries
          _api200(),
        ])
        ..refreshAnswers.addAll([
          _refreshTo('A2', open: false),
          _refreshTo('B2', open: false),
        ]);

      await http.runWithClient(() async {
        final a = _TestService().withAuth(_requestAs('GET'));
        await backend.nextRefreshCall;
        await _signOut();
        await _signIn('B');

        final b1 = _TestService().withAuth(_requestAs('POST'));
        await backend.nextRefreshCall;
        // A's refresh lands while B's is still in flight.
        backend.refreshAnswers[0].gate.complete();
        await expectLater(a, _sessionChanged);

        final b2 = _TestService().withAuth(_requestAs('PATCH'));
        await backend.nextApiCall;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        backend.refreshAnswers[1].gate.complete();
        expect((await b1).statusCode, 200);
        expect((await b2).statusCode, 200);
      }, backend.client);

      expect(backend.refreshedWith, ['refresh-A', 'refresh-B']);
      final bAuthorizations = [
        for (final s in backend.seen)
          if (s.path == _api.path && s.method != 'GET') s.authorization,
      ];
      expect(bAuthorizations, [
        'Bearer access-B',
        'Bearer access-B',
        'Bearer access-B2',
        'Bearer access-B2',
      ]);
      expect(await AuthStorage.getAccessToken(), 'access-B2');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B2');
    });
  });

  group('same session', () {
    test('a 401 refreshes with its own refresh token, stores the rotated '
        'pair and retries with the new access token', () async {
      final backend = _Backend()
        ..apiAnswers.addAll([_api401(open: true), _api200()])
        ..refreshAnswers.add(_refreshTo('A2'));

      final res = await http.runWithClient(
        () => _TestService().withAuth(_requestAs('PATCH')),
        backend.client,
      );

      expect(res.statusCode, 200);
      expect(backend.refreshedWith, ['refresh-A']);
      expect(backend.apiAuthorizations, [
        'Bearer access-A',
        'Bearer access-A2',
      ]);
      expect(await AuthStorage.getAccessToken(), 'access-A2');
      expect(await AuthStorage.getRefreshToken(), 'refresh-A2');
    });

    test('a refresh does not start a new session: a request sent before it '
        'still gets its reply', () async {
      final backend = _Backend()
        ..apiAnswers.addAll([
          (gate: Completer<void>(), status: 200), // slow request
          _api401(open: true), // another request's 401
          _api200(), // its retry
        ])
        ..refreshAnswers.add(_refreshTo('A2'));

      await http.runWithClient(() async {
        final slow = _TestService().withAuth(_requestAs('GET'));
        await backend.nextApiCall;
        expect(
          (await _TestService().withAuth(_requestAs('POST'))).statusCode,
          200,
        );
        backend.apiAnswers.first.gate.complete();
        expect((await slow).statusCode, 200);
      }, backend.client);

      expect(await AuthStorage.getAccessToken(), 'access-A2');
    });
  });

  group('AuthStorage', () {
    test('every sign-in and sign-out starts a new session epoch; a refresh '
        'keeps it', () async {
      final start = AuthStorage.sessionEpoch;
      await _signIn('A');
      final a = AuthStorage.sessionEpoch;
      expect(
        await AuthStorage.saveRefreshedTokens(
          epoch: a,
          accessToken: 'access-A2',
          refreshToken: 'refresh-A2',
        ),
        isTrue,
      );
      expect(AuthStorage.sessionEpoch, a);
      await _signOut();
      await _signIn('A');

      expect(a, greaterThan(start));
      expect(AuthStorage.sessionEpoch, a + 2);
    });

    test('a refresh save racing a sign-out and the next sign-in never leaves '
        "a mixed pair: B's tokens win", () async {
      FlutterSecureStoragePlatform.instance = _SlowRefreshWriteStorage({
        'access_token': 'access-A',
        'refresh_token': 'refresh-A',
      });
      final epoch = AuthStorage.sessionEpoch;
      final saved = AuthStorage.saveRefreshedTokens(
        epoch: epoch,
        accessToken: 'access-A2',
        refreshToken: 'refresh-A2',
      );
      final signedOut = _signOut();
      final signedIn = _signIn('B');
      await Future.wait([saved, signedOut, signedIn]);

      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
    });

    test('a refresh save that started writing before a sign-out is cleared '
        'by it, not left half-written', () async {
      FlutterSecureStoragePlatform.instance = _SlowRefreshWriteStorage({
        'access_token': 'access-A',
        'refresh_token': 'refresh-A',
      });
      final epoch = AuthStorage.sessionEpoch;
      final saved = AuthStorage.saveRefreshedTokens(
        epoch: epoch,
        accessToken: 'access-A2',
        refreshToken: 'refresh-A2',
      );
      // Let the save get past its epoch check and into its writes.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await Future.wait([saved, _signOut()]);

      expect(await AuthStorage.getAccessToken(), isNull);
      expect(await AuthStorage.getRefreshToken(), isNull);
    });

    test("a stale refresh save writes nothing and reports it", () async {
      final epoch = AuthStorage.sessionEpoch;
      await _signOut();
      await _signIn('B');

      expect(
        await AuthStorage.saveRefreshedTokens(
          epoch: epoch,
          accessToken: 'access-A2',
          refreshToken: 'refresh-A2',
        ),
        isFalse,
      );
      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
    });
  });
}
