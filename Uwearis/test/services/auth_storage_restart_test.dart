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

final _api = Uri.parse('https://api.test/api/v1/thing');

/// A backend with rotating, single-use refresh tokens: `refresh-X` becomes
/// `refresh-X2`, `refresh-X2` becomes `refresh-X3`, … The API accepts only
/// [validAccess]. A refresh token sent a second time is a reuse — the real
/// backend would then revoke every session of that user.
class _Backend {
  _Backend(this.validAccess);
  String validAccess;
  final refreshedWith = <String>[];

  /// When set, the next refresh is applied (the token is spent) but its
  /// reply waits for this completer.
  Completer<void>? holdNextReply;

  List<String> get reused => [
    for (final (i, t) in refreshedWith.indexed)
      if (refreshedWith.indexOf(t) != i) t,
  ];

  static String _next(String token) {
    final m = RegExp(r'^(.*?)(\d*)$').firstMatch(token)!;
    final n = m[2]!.isEmpty ? 2 : int.parse(m[2]!) + 1;
    return '${m[1]}$n';
  }

  MockClient client() => MockClient((req) async {
    if (req.url.path.endsWith('/auth/refresh')) {
      final sent = (jsonDecode(req.body) as Map)['refresh_token'] as String;
      refreshedWith.add(sent);
      final rotated = _next(sent);
      final access = rotated.replaceFirst('refresh-', 'access-');
      validAccess = access;
      final hold = holdNextReply;
      holdNextReply = null;
      if (hold != null) await hold.future;
      return jsonResponse(
        envelope({'access_token': access, 'refresh_token': rotated}),
      );
    }
    final ok = req.headers['Authorization'] == 'Bearer $validAccess';
    return http.Response('{}', ok ? 200 : 401);
  });
}

Future<http.Response> _call() => _TestService().withAuth(
  (t) => http.get(_api, headers: {'Authorization': 'Bearer $t'}),
);

Future<({String? access, String? refresh})> _tokens() async => (
  access: await AuthStorage.getAccessToken(),
  refresh: await AuthStorage.getRefreshToken(),
);

const _signedOut = (access: null, refresh: null);

void main() {
  late ScriptedSecureStorage keychain;
  late ScriptedPrefsStore prefs;

  /// A launch that finds A signed in from an earlier run.
  setUp(() {
    keychain = installKeychain({
      'access_token': 'access-A',
      'refresh_token': 'refresh-A',
    });
    prefs = installPrefs();
    simulateRestart();
  });

  group('normal flows survive a restart', () {
    test('sign-in, restart: still signed in, nothing left marked', () async {
      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      simulateRestart();

      expect(await _tokens(), (access: 'access-B', refresh: 'refresh-B'));
      expect(await prefs.stored(), isEmpty);
    });

    test('refresh, restart: the rotated pair is used', () async {
      final backend = _Backend('access-A2');
      final res = await http.runWithClient(_call, backend.client);
      expect(res.statusCode, 200);
      expect(await prefs.stored(), isEmpty);

      simulateRestart();
      expect(await _tokens(), (access: 'access-A2', refresh: 'refresh-A2'));
      expect(backend.reused, isEmpty);
    });

    test('sign-out, restart: signed out', () async {
      await AuthStorage.clear();
      simulateRestart();

      expect(await _tokens(), _signedOut);
      expect(keychain.data, isEmpty);
      expect(await prefs.stored(), isEmpty);
    });

    test('concurrent 401s of one session: one refresh, all retried, nothing '
        'left marked', () async {
      final backend = _Backend('access-A2');
      final results = await http.runWithClient(
        () => Future.wait([_call(), _call(), _call()]),
        backend.client,
      );

      expect(results.map((r) => r.statusCode), [200, 200, 200]);
      expect(backend.refreshedWith, ['refresh-A']);
      expect(await prefs.stored(), isEmpty);
    });
  });

  group('a rotated refresh token that never reached the keychain is never '
      'sent after a restart', () {
    test('the app is killed after the refresh was sent', () async {
      final backend = _Backend('access-A2')..holdNextReply = Completer();
      final held = backend.holdNextReply!;
      final killed = http.runWithClient(_call, backend.client);
      await pumpEventQueue();
      expect(backend.refreshedWith, ['refresh-A']);

      simulateRestart();
      expect(await _tokens(), _signedOut);
      // The dead process never gets its reply; end its refresh flight so it
      // can't be joined by a later test's.
      held.completeError(Exception('process killed'));
      await expectLater(killed, throwsException);

      await http.runWithClient(
        () => expectLater(_call(), throwsA(isA<AuthExpiredException>())),
        backend.client,
      );
      expect(backend.reused, isEmpty);
      expect(keychain.data, isEmpty);
    });

    for (final failing in ['access_token', 'refresh_token']) {
      test('$failing write fails and so does the cleanup', () async {
        keychain
          ..failNextWrite.add(failing)
          ..failDeletes.addAll(['access_token', 'refresh_token']);
        final backend = _Backend('access-A2');
        await http.runWithClient(
          () => expectLater(_call(), throwsException),
          backend.client,
        );
        expect(keychain.data['refresh_token'], isNotNull);

        simulateRestart();
        expect(await _tokens(), _signedOut);
        await http.runWithClient(
          () => expectLater(_call(), throwsA(isA<AuthExpiredException>())),
          backend.client,
        );
        expect(backend.refreshedWith, ['refresh-A']);
      });
    }

    test('the leftovers are deleted at the next launch that can', () async {
      keychain
        ..failNextWrite.add('access_token')
        ..failDeletes.addAll(['access_token', 'refresh_token']);
      await http.runWithClient(
        () => expectLater(_call(), throwsException),
        _Backend('access-A2').client,
      );

      simulateRestart();
      expect(await _tokens(), _signedOut);
      keychain.failDeletes.clear();
      simulateRestart();
      expect(await _tokens(), _signedOut);
      expect(keychain.data, isEmpty);
      expect(await prefs.stored(), isEmpty);
    });

    test('the pair is stored but un-marking it fails: signed out after a '
        'restart rather than trusted', () async {
      prefs.failRemoves = true;
      final backend = _Backend('access-A2');
      final res = await http.runWithClient(_call, backend.client);
      expect(res.statusCode, 200);
      // This process knows the pair landed.
      expect(await _tokens(), (access: 'access-A2', refresh: 'refresh-A2'));

      simulateRestart();
      expect(await _tokens(), _signedOut);
      expect(backend.reused, isEmpty);
    });
  });

  group('the marker failing', () {
    test('it cannot be written before a refresh: nothing is sent and the '
        'session stays usable', () async {
      prefs.failWrites = true;
      final backend = _Backend('access-A2');

      await http.runWithClient(() async {
        final error = await _call().then<Object?>(
          (_) => null,
          onError: (e) => e,
        );
        expect(error, isNotNull);
        expect(error, isNot(isA<AuthExpiredException>()));
      }, backend.client);
      expect(backend.refreshedWith, isEmpty);
      expect(await _tokens(), (access: 'access-A', refresh: 'refresh-A'));

      prefs.failWrites = false;
      final res = await http.runWithClient(_call, backend.client);
      expect(res.statusCode, 200);
      expect(backend.refreshedWith, ['refresh-A']);
    });

    test('it cannot be read at launch: the stored tokens are not used, nor '
        'deleted', () async {
      prefs.failReads = true;
      simulateRestart();

      expect(await _tokens(), _signedOut);
      expect(keychain.data, {
        'access_token': 'access-A',
        'refresh_token': 'refresh-A',
      });

      prefs.failReads = false;
      simulateRestart();
      expect(await _tokens(), (access: 'access-A', refresh: 'refresh-A'));
    });

    test('it cannot be written at sign-in: the sign-in fails, nothing is '
        'stored, and the next one works', () async {
      await AuthStorage.clear();
      prefs.failWrites = true;

      await expectLater(
        AuthStorage.startSession(
          accessToken: 'access-B',
          refreshToken: 'refresh-B',
        ),
        throwsException,
      );
      expect(await _tokens(), _signedOut);
      expect(keychain.data, isEmpty);

      prefs.failWrites = false;
      await AuthStorage.startSession(
        accessToken: 'access-C',
        refreshToken: 'refresh-C',
      );
      expect(await _tokens(), (access: 'access-C', refresh: 'refresh-C'));
      simulateRestart();
      expect(await _tokens(), (access: 'access-C', refresh: 'refresh-C'));
    });

    test('it cannot be written at sign-out, but the deletes work: signed '
        'out', () async {
      prefs.failWrites = true;
      await AuthStorage.clear();
      simulateRestart();

      expect(await _tokens(), _signedOut);
      expect(keychain.data, isEmpty);
    });
  });

  group('sign-out whose deletes fail', () {
    test('stays signed out after a restart', () async {
      keychain.failDeletes.addAll(['access_token', 'refresh_token']);
      await AuthStorage.clear();
      expect(await _tokens(), _signedOut);

      simulateRestart();
      expect(await _tokens(), _signedOut);

      keychain.failDeletes.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      expect(await _tokens(), (access: 'access-B', refresh: 'refresh-B'));
      simulateRestart();
      expect(await _tokens(), (access: 'access-B', refresh: 'refresh-B'));
    });

    test("B's sign-in killed halfway after A's failed sign-out: A's access "
        "token is not used for B after a restart", () async {
      keychain.failDeletes.addAll(['access_token', 'refresh_token']);
      await AuthStorage.clear();
      keychain.failDeletes.clear();
      keychain.holdNextWrite['access_token'] = Completer();

      unawaited(
        AuthStorage.startSession(
          accessToken: 'access-B',
          refreshToken: 'refresh-B',
        ),
      );
      await pumpEventQueue();
      expect(keychain.data, {
        'access_token': 'access-A',
        'refresh_token': 'refresh-B',
      });

      simulateRestart();
      expect(await _tokens(), _signedOut);
    });
  });

  group('session switching', () {
    test('a launch that clears an earlier run\'s leftovers does not touch a '
        'sign-in made before its first read', () async {
      keychain.failDeletes.addAll(['access_token', 'refresh_token']);
      await AuthStorage.clear();
      keychain.failDeletes.clear();

      simulateRestart();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );

      expect(await _tokens(), (access: 'access-B', refresh: 'refresh-B'));
      simulateRestart();
      expect(await _tokens(), (access: 'access-B', refresh: 'refresh-B'));
    });

    test('A → B → C while A\'s refresh is in flight: C is stored, trusted '
        'after a restart, and A\'s late reply writes nothing', () async {
      final backend = _Backend('access-A2')..holdNextReply = Completer();
      final held = backend.holdNextReply!;
      final aCall = http.runWithClient(_call, backend.client);
      await pumpEventQueue();
      expect(backend.refreshedWith, ['refresh-A']);

      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'access-C',
        refreshToken: 'refresh-C',
      );
      held.complete();
      await expectLater(aCall, throwsA(isA<SessionChangedException>()));

      expect(keychain.data, {
        'access_token': 'access-C',
        'refresh_token': 'refresh-C',
      });
      expect(await prefs.stored(), isEmpty);
      simulateRestart();
      expect(await _tokens(), (access: 'access-C', refresh: 'refresh-C'));
    });
  });
}
