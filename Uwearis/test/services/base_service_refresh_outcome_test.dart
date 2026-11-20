import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// How the backend answers a refresh it has received.
typedef _Reply = FutureOr<http.Response> Function(String rotated);

/// A backend with rotating, single-use refresh tokens: `refresh-X` becomes
/// `refresh-X2`, then `refresh-X3`, … A refresh it receives is applied —
/// the token spent — before [reply] decides what reaches the app, the way a
/// reply lost after the backend committed looks. The API accepts only the
/// newest access token of each account.
class _Backend {
  _Backend({_Reply? reply}) : reply = reply ?? _ok;

  _Reply reply;
  final refreshedWith = <String>[];
  final _validAccess = <String, String>{
    'A': 'access-A',
    'B': 'access-B',
    'C': 'access-C',
  };

  /// Every access token starts out expired, so the first call refreshes.
  void expireAll() => _validAccess.updateAll((_, _) => 'expired');

  List<String> get reused => [
    for (final (i, t) in refreshedWith.indexed)
      if (refreshedWith.indexOf(t) != i) t,
  ];

  static http.Response _ok(String rotated) => jsonResponse(
    envelope({
      'access_token': rotated.replaceFirst('refresh-', 'access-'),
      'refresh_token': rotated,
    }),
  );

  static String _account(String token) => token.split('-')[1][0];

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
      _validAccess[_account(sent)] = rotated.replaceFirst(
        'refresh-',
        'access-',
      );
      return reply(rotated);
    }
    final token = req.headers['Authorization']!.replaceFirst('Bearer ', '');
    final account = token.startsWith('access-') ? _account(token) : '';
    return http.Response('{}', _validAccess[account] == token ? 200 : 401);
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

/// The outcomes after which the backend may or may not have rotated the
/// token: nothing the app received says which.
final _unknownOutcomes = <String, _Reply>{
  'a timeout': (_) => throw TimeoutException('refresh reply lost'),
  'a dropped connection': (_) =>
      throw http.ClientException('Connection reset by peer'),
  'a socket error': (_) =>
      throw const SocketException('Connection closed while receiving data'),
  'a 500': (_) => http.Response('{"success":false}', 500),
  'a 503': (_) => http.Response('', 503),
};

/// A 200: the token was rotated, but the reply carries no usable pair.
final _incompleteReplies = <String, _Reply>{
  'a body that is not JSON': (_) => http.Response('<html>', 200),
  'a body that is not an object': (_) => http.Response('[]', 200),
  'no data': (_) => jsonResponse({'success': true}),
  'data that is not an object': (_) => jsonResponse(envelope('tokens')),
  'no refresh token': (r) =>
      jsonResponse(envelope({'access_token': 'access-x'})),
  'a non-string token': (r) =>
      jsonResponse(envelope({'access_token': 'access-x', 'refresh_token': 7})),
};

/// The backend refused the token: it was not rotated, and won't be.
final _rejections = <String, _Reply>{
  'a 401': (_) => jsonResponse({
    'success': false,
    'error_code': 'INVALID_TOKEN',
  }, status: 401),
  'a 403': (_) => http.Response('', 403),
};

void main() {
  late ScriptedSecureStorage keychain;

  /// A launch that finds A signed in, its access token expired.
  setUp(() {
    keychain = installKeychain({
      'access_token': 'access-A',
      'refresh_token': 'refresh-A',
    });
    installPrefs();
    simulateRestart();
  });

  Future<void> expectSpentTokenNeverResent(_Backend backend) async {
    await http.runWithClient(() async {
      // The same session's next 401, and a concurrent pair of them.
      await expectLater(_call(), throwsA(isA<AuthExpiredException>()));
      await expectLater(
        Future.wait([_call(), _call()]),
        throwsA(isA<AuthExpiredException>()),
      );
    }, backend.client);
    expect(backend.refreshedWith, ['refresh-A']);
    expect(await _tokens(), _signedOut);

    simulateRestart();
    expect(await _tokens(), _signedOut);
    await http.runWithClient(
      () => expectLater(_call(), throwsA(isA<AuthExpiredException>())),
      backend.client,
    );
    expect(backend.refreshedWith, ['refresh-A']);
    expect(backend.reused, isEmpty);
  }

  test('a refresh that succeeds stores the pair and retries the request '
      'once', () async {
    final backend = _Backend()..expireAll();
    final res = await http.runWithClient(_call, backend.client);

    expect(res.statusCode, 200);
    expect(backend.refreshedWith, ['refresh-A']);
    expect(await _tokens(), (access: 'access-A2', refresh: 'refresh-A2'));

    final again = await http.runWithClient(_call, backend.client);
    expect(again.statusCode, 200);
    expect(backend.refreshedWith, ['refresh-A']);
  });

  group('reproduction: the next 401 after an unknown outcome', () {
    for (final name in ['a timeout', 'a dropped connection']) {
      test('$name: refresh-A is not sent a second time, whatever the first '
          'call threw', () async {
        final backend = _Backend(reply: _unknownOutcomes[name])..expireAll();
        Future<void> attempt() => http.runWithClient(
          () => _call().then<void>((_) {}, onError: (_) {}),
          backend.client,
        );

        await attempt();
        backend.reply = _Backend._ok;
        await attempt();

        expect(backend.reused, isEmpty);
        expect(backend.refreshedWith, ['refresh-A']);
      });
    }
  });

  group('a refresh whose outcome is unknown ends the session', () {
    for (final MapEntry(key: name, value: reply) in _unknownOutcomes.entries) {
      test('$name: AuthExpiredException, and the token is never sent '
          'again', () async {
        final backend = _Backend(reply: reply)..expireAll();

        await http.runWithClient(
          () => expectLater(_call(), throwsA(isA<AuthExpiredException>())),
          backend.client,
        );

        await expectSpentTokenNeverResent(backend);
      });
    }
  });

  group('a 200 without a usable token pair ends the session', () {
    for (final MapEntry(key: name, value: reply)
        in _incompleteReplies.entries) {
      test('$name: AuthExpiredException, and the spent token is never sent '
          'again', () async {
        final backend = _Backend(reply: reply)..expireAll();

        await http.runWithClient(
          () => expectLater(_call(), throwsA(isA<AuthExpiredException>())),
          backend.client,
        );

        await expectSpentTokenNeverResent(backend);
      });
    }
  });

  group('a rejected refresh ends the session', () {
    for (final MapEntry(key: name, value: reply) in _rejections.entries) {
      test('$name: AuthExpiredException, and the rejected token is not sent '
          'again', () async {
        final backend = _Backend(reply: reply)..expireAll();

        await http.runWithClient(
          () => expectLater(_call(), throwsA(isA<AuthExpiredException>())),
          backend.client,
        );

        await expectSpentTokenNeverResent(backend);
      });
    }
  });

  test('concurrent 401s share the one refresh, and all end with the '
      'session', () async {
    final backend = _Backend(
      reply: (_) => throw TimeoutException('refresh reply lost'),
    )..expireAll();

    await http.runWithClient(
      () => expectLater(
        Future.wait([_call(), _call(), _call()]),
        throwsA(isA<AuthExpiredException>()),
      ),
      backend.client,
    );

    await expectSpentTokenNeverResent(backend);
  });

  group('another session', () {
    test("A's refresh failing after B signed in is SessionChangedException, "
        "and B's session is untouched", () async {
      final held = Completer<http.Response>();
      final backend = _Backend(reply: (_) => held.future)..expireAll();
      final aCall = http.runWithClient(_call, backend.client);
      await pumpEventQueue();
      expect(backend.refreshedWith, ['refresh-A']);

      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      held.completeError(TimeoutException('refresh reply lost'));
      await expectLater(aCall, throwsA(isA<SessionChangedException>()));

      expect(await _tokens(), (access: 'access-B', refresh: 'refresh-B'));
      backend.reply = _Backend._ok;
      final res = await http.runWithClient(_call, backend.client);
      expect(res.statusCode, 200);
      expect(backend.refreshedWith, ['refresh-A', 'refresh-B']);
      expect(await _tokens(), (access: 'access-B2', refresh: 'refresh-B2'));
    });

    test("A → B → C: A's failing refresh does not hold up or answer C's, and "
        "deletes nothing of C's", () async {
      final held = Completer<http.Response>();
      final backend = _Backend(reply: (_) => held.future)..expireAll();
      final aCall = http.runWithClient(_call, backend.client);
      await pumpEventQueue();

      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'expired-C',
        refreshToken: 'refresh-C',
      );

      backend.reply = _Backend._ok;
      final cRes = await http.runWithClient(_call, backend.client);
      expect(cRes.statusCode, 200);
      expect(backend.refreshedWith, ['refresh-A', 'refresh-C']);

      held.complete(http.Response('', 500));
      await expectLater(aCall, throwsA(isA<SessionChangedException>()));
      expect(keychain.data, {
        'access_token': 'access-C2',
        'refresh_token': 'refresh-C2',
      });
      expect(await _tokens(), (access: 'access-C2', refresh: 'refresh-C2'));
    });

    test('after the session ended this way, sign-out and the next sign-in '
        'go through, and the new session refreshes normally', () async {
      final backend = _Backend(
        reply: (_) => throw TimeoutException('refresh reply lost'),
      )..expireAll();
      await http.runWithClient(
        () => expectLater(_call(), throwsA(isA<AuthExpiredException>())),
        backend.client,
      );

      await AuthStorage.clear();
      await AuthStorage.startSession(
        accessToken: 'expired-B',
        refreshToken: 'refresh-B',
      );
      backend.reply = _Backend._ok;
      final res = await http.runWithClient(_call, backend.client);

      expect(res.statusCode, 200);
      expect(backend.refreshedWith, ['refresh-A', 'refresh-B']);
      expect(await _tokens(), (access: 'access-B2', refresh: 'refresh-B2'));
      simulateRestart();
      expect(await _tokens(), (access: 'access-B2', refresh: 'refresh-B2'));
    });
  });
}
