import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/services/base_service.dart';

import '../helpers/mock_http.dart';
import '../helpers/scripted_auth_storage.dart';

class _TestService with BaseService {}

ScriptedSecureStorage _install(String account) => installKeychain({
  'access_token': 'access-$account',
  'refresh_token': 'refresh-$account',
});

final _api = Uri.parse('https://api.test/api/v1/thing');

/// A backend whose API accepts only [validAccess], and whose refresh
/// endpoint rotates to `…-A<n>`. Records the refresh tokens it was sent.
class _Backend {
  _Backend(this.validAccess);
  String validAccess;
  final refreshedWith = <String>[];

  MockClient client() => MockClient((req) async {
    if (req.url.path.endsWith('/auth/refresh')) {
      final sent = (jsonDecode(req.body) as Map)['refresh_token'] as String;
      refreshedWith.add(sent);
      final n = refreshedWith.length + 1;
      return jsonResponse(
        envelope({
          'access_token': 'access-A$n',
          'refresh_token': 'refresh-A$n',
        }),
      );
    }
    final ok = req.headers['Authorization'] == 'Bearer $validAccess';
    return http.Response('{}', ok ? 200 : 401);
  });
}

Future<http.Response> _call() => _TestService().withAuth(
  (t) => http.get(_api, headers: {'Authorization': 'Bearer $t'}),
);

void main() {
  // AuthStorage's session state is static: start every test from a clean
  // sign-in so one test's failure can't carry into the next.
  setUp(() async {
    installPrefs();
    _install('A');
    await AuthStorage.startSession(
      accessToken: 'access-A',
      refreshToken: 'refresh-A',
    );
  });

  group('a refresh whose token pair fails to save', () {
    for (final failing in ['access_token', 'refresh_token']) {
      test('$failing write fails: the session is unusable from then on and '
          'the spent refresh token is never sent again', () async {
        final storage = _install('A')..failNextWrite.add(failing);
        final backend = _Backend('access-A2');

        await http.runWithClient(() async {
          await expectLater(_call(), throwsException);
          expect(await AuthStorage.getAccessToken(), isNull);
          expect(await AuthStorage.getRefreshToken(), isNull);

          // The next request finds no session instead of refreshing again.
          await expectLater(_call(), throwsA(isA<AuthExpiredException>()));
        }, backend.client);

        expect(backend.refreshedWith, ['refresh-A']);
        expect(storage.data.values, isNot(contains('refresh-A')));
        expect(storage.data, isEmpty);
      });
    }

    test('the cleanup failing too still leaves no usable session in this '
        'process, and the queue keeps going', () async {
      final storage = _install('A')
        ..failNextWrite.add('refresh_token')
        ..failDeletes.addAll(['access_token', 'refresh_token']);
      final backend = _Backend('access-A2');

      await http.runWithClient(() async {
        await expectLater(_call(), throwsException);
        expect(await AuthStorage.getAccessToken(), isNull);
        expect(await AuthStorage.getRefreshToken(), isNull);
        await expectLater(_call(), throwsA(isA<AuthExpiredException>()));
      }, backend.client);
      expect(backend.refreshedWith, ['refresh-A']);

      storage.failDeletes.clear();
      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
    });

    test("A's failed save while B is signing in neither deletes B's tokens "
        "nor makes B's session unusable", () async {
      final storage = _install('A');
      final held = Completer<void>();
      storage.holdNextWrite['refresh_token'] = held;
      final epoch = AuthStorage.sessionEpoch;

      final aSave = AuthStorage.saveRefreshedTokens(
        epoch: epoch,
        accessToken: 'access-A2',
        refreshToken: 'refresh-A2',
      );
      await Future<void>.delayed(Duration.zero);
      final signedOut = AuthStorage.clear();
      final signedIn = AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      held.completeError(Exception('keychain write failed'));
      await expectLater(aSave, throwsException);
      await signedOut;
      await signedIn;

      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
      expect(storage.data, {
        'access_token': 'access-B',
        'refresh_token': 'refresh-B',
      });
    });
  });

  group('a sign-in whose token pair fails to save', () {
    test('is not left half-stored and usable', () async {
      final storage = _install('A');
      await AuthStorage.clear();
      storage.failNextWrite.add('access_token');

      await expectLater(
        AuthStorage.startSession(
          accessToken: 'access-B',
          refreshToken: 'refresh-B',
        ),
        throwsException,
      );

      expect(await AuthStorage.getAccessToken(), isNull);
      expect(await AuthStorage.getRefreshToken(), isNull);
      expect(storage.data, isEmpty);

      await AuthStorage.startSession(
        accessToken: 'access-C',
        refreshToken: 'refresh-C',
      );
      expect(await AuthStorage.getAccessToken(), 'access-C');
      expect(await AuthStorage.getRefreshToken(), 'refresh-C');
    });
  });

  group('clear() failing', () {
    test('does not throw, signs the process out anyway, and the next sign-in '
        'still works', () async {
      final storage = _install('A')
        ..failDeletes.addAll(['access_token', 'refresh_token']);

      await AuthStorage.clear();

      expect(await AuthStorage.getAccessToken(), isNull);
      expect(await AuthStorage.getRefreshToken(), isNull);

      storage.failDeletes.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
    });

    test('one key failing to delete still deletes the other', () async {
      final storage = _install('A')..failDeletes.add('access_token');

      await AuthStorage.clear();

      expect(storage.data.containsKey('refresh_token'), isFalse);
    });
  });

  group('unchanged', () {
    test('a normal refresh stores the rotated pair and retries', () async {
      final storage = _install('A');
      final backend = _Backend('access-A2');

      final res = await http.runWithClient(_call, backend.client);

      expect(res.statusCode, 200);
      expect(backend.refreshedWith, ['refresh-A']);
      expect(storage.data, {
        'access_token': 'access-A2',
        'refresh_token': 'refresh-A2',
      });
    });

    test('sign-in, then sign-out', () async {
      final storage = _install('A');
      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      expect(await AuthStorage.getAccessToken(), 'access-B');

      await AuthStorage.clear();
      expect(await AuthStorage.getAccessToken(), isNull);
      expect(storage.data, isEmpty);
    });

    test('tokens already in the keychain are read as they are', () async {
      _install('A');
      expect(await AuthStorage.getAccessToken(), 'access-A');
      expect(await AuthStorage.getRefreshToken(), 'refresh-A');
    });
  });
}
