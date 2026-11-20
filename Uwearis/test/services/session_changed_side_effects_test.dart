import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// Transitive via flutter_secure_storage; only its platform setter is used.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/services/base_service.dart';

import '../helpers/mock_http.dart';

// Audit 2026-11-20 (SessionChangedException side effects). Skipped tests
// assert the proposed behaviour and fail today; the rest pin what holds.

const _proposed =
    'Audit finding, not fixed yet — see '
    'session_changed_side_effects_test.dart';

class _TestService with BaseService {}

final _api = Uri.parse('https://api.test/api/v1/thing');

Future<void> _signIn(String account) => AuthStorage.startSession(
  accessToken: 'access-$account',
  refreshToken: 'refresh-$account',
);

/// Secure storage whose next write to [failOnKey] throws.
class _FailingWriteStorage extends TestFlutterSecureStoragePlatform {
  _FailingWriteStorage(super.data, {this.failOnKey});

  /// Writes to this key throw once.
  String? failOnKey;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (key == failOnKey) {
      failOnKey = null;
      throw Exception('keychain write failed');
    }
    return super.write(key: key, value: value, options: options);
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-A',
      'refresh_token': 'refresh-A',
    });
  });

  group('A. SessionChangedException propagation', () {
    test('a 401 that lands after AuthExpiredHandler cleared the session '
        '(nobody signed in) should stay an AuthExpiredException, which the '
        'handler dedupes — today it is a SessionChangedException that a '
        "page's generic catch shows as an error", () async {
      final second = Completer<void>();
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response('{}', 401); // A's session is dead
        }
        if (req.url.query == 'n=2') await second.future;
        return http.Response('{}', 401);
      });

      await http.runWithClient(() async {
        final first = _TestService().withAuth(
          (t) => http.get(_api.replace(query: 'n=1'), headers: {'t': t}),
        );
        final late = _TestService().withAuth(
          (t) => http.get(_api.replace(query: 'n=2'), headers: {'t': t}),
        );
        await expectLater(first, throwsA(isA<AuthExpiredException>()));
        // What AuthExpiredHandler does before its dialog.
        await AuthStorage.clear();
        second.complete();
        await expectLater(late, throwsA(isA<AuthExpiredException>()));
      }, () => client);
    }, skip: _proposed);

    test(
      'the same late 401 once B has signed in stays a '
      "SessionChangedException — never an expiry that could sign B out",
      () async {
        final second = Completer<void>();
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/auth/refresh')) {
            return http.Response('{}', 401);
          }
          if (req.url.query == 'n=2') await second.future;
          return http.Response('{}', 401);
        });

        await http.runWithClient(() async {
          final first = _TestService().withAuth(
            (t) => http.get(_api.replace(query: 'n=1'), headers: {'t': t}),
          );
          final late = _TestService().withAuth(
            (t) => http.get(_api.replace(query: 'n=2'), headers: {'t': t}),
          );
          await expectLater(first, throwsA(isA<AuthExpiredException>()));
          await AuthStorage.clear();
          await _signIn('B');
          second.complete();
          await expectLater(late, throwsA(isA<SessionChangedException>()));
        }, () => client);

        expect(await AuthStorage.getAccessToken(), 'access-B');
      },
    );

    /// Account A's pull-to-refresh is in flight; A signs out, B signs in
    /// (providers invalidated, B's list loads), then A's reply lands. The
    /// second backend call is A's refresh. One client for the whole test:
    /// `runWithClient` calls its factory per request.
    MockClient heldSecondCall(Completer<void> release, Object data) {
      var calls = 0;
      return MockClient((req) async {
        if (++calls == 2) await release.future;
        return jsonResponse(envelope(data));
      });
    }

    test("tripsProvider: A's stale refresh landing after B's list loaded "
        "doesn't replace it with an error (fixed: Finding #2)", () async {
      final release = Completer<void>();
      final client = heldSecondCall(release, {'items': <Object>[]});
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);

      await http.runWithClient(() async {
        final sub = container.listen(tripsProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(tripsProvider.future);

        final stale = container.read(tripsProvider.notifier).refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await AuthStorage.clear();
        await _signIn('B');
        container.invalidate(tripsProvider);
        await container.read(tripsProvider.future);
        release.complete();
        await stale;
      }, () => client);

      final state = container.read(tripsProvider);
      expect(state.hasError, isFalse, reason: '$state');
      expect(state.hasValue, isTrue);
    });

    test('outfitsProvider (ListRefetchGuard): the same stale refresh is '
        'dropped — its generation guard already protects it', () async {
      final release = Completer<void>();
      final client = heldSecondCall(release, {'items': <Object>[], 'total': 0});
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);

      await http.runWithClient(() async {
        final sub = container.listen(outfitsProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(outfitsProvider.future);

        final stale = container.read(outfitsProvider.notifier).refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await AuthStorage.clear();
        await _signIn('B');
        container.invalidate(outfitsProvider);
        await container.read(outfitsProvider.future);
        release.complete();
        await stale;
      }, () => client);

      final state = container.read(outfitsProvider);
      expect(state.hasError, isFalse, reason: '$state');
      expect(state.hasValue, isTrue);
    });
  });

  group('B. AuthStorage write queue', () {
    test('a failed write fails only its own call; clear() and the next '
        'sign-in still run', () async {
      FlutterSecureStoragePlatform.instance = _FailingWriteStorage({
        'access_token': 'access-A',
        'refresh_token': 'refresh-A',
      }, failOnKey: 'access_token');

      await expectLater(_signIn('B'), throwsException);
      await AuthStorage.clear();
      expect(await AuthStorage.getAccessToken(), isNull);
      expect(await AuthStorage.getRefreshToken(), isNull);

      await _signIn('C');
      expect(await AuthStorage.getAccessToken(), 'access-C');
      expect(await AuthStorage.getRefreshToken(), 'refresh-C');
    });

    test('a refresh save whose refresh-token write fails leaves no '
        'new-access + spent-refresh pair behind (fixed: Finding #3)', () async {
      FlutterSecureStoragePlatform.instance = _FailingWriteStorage({
        'access_token': 'access-A',
        'refresh_token': 'refresh-A',
      }, failOnKey: 'refresh_token');

      await expectLater(
        AuthStorage.saveRefreshedTokens(
          epoch: AuthStorage.sessionEpoch,
          accessToken: 'access-A2',
          refreshToken: 'refresh-A2',
        ),
        throwsException,
      );

      final pair = (
        await AuthStorage.getAccessToken(),
        await AuthStorage.getRefreshToken(),
      );
      expect(
        pair,
        anyOf(equals(('access-A', 'refresh-A')), equals((null, null))),
      );
    });

    test('reads wait for a sign-in queued before them', () async {
      final signedIn = _signIn('B');
      final read = AuthStorage.getAccessToken();
      await signedIn;
      expect(await read, 'access-B');
    });
  });
}
