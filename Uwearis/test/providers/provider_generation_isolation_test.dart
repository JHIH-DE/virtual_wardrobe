import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/providers/style_profile_provider.dart';
import 'package:uwearis/core/providers/style_taste_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/auth_storage.dart';

import '../helpers/mock_http.dart';
import '../helpers/scripted_auth_storage.dart';

/// One provider under test, reduced to what the scenarios need. [idOf] reads
/// back which account and version a loaded value came from (`A1`, `B2`, …),
/// and [data] is the backend reply carrying that id.
class _Case {
  _Case._({
    required this.name,
    required this.data,
    required this.load,
    required this.refresh,
    required this.invalidate,
    required this.listen,
    required this.notifier,
    required this.state,
  });

  static _Case of<N extends AsyncNotifier<T>, T>(
    String name,
    AsyncNotifierProvider<N, T> provider, {
    required Object Function(String id) data,
    required String Function(T value) idOf,
    required Future<void> Function(N notifier) refresh,
  }) => _Case._(
    name: name,
    data: data,
    load: (c) async => idOf(await c.read(provider.future)),
    refresh: (c) => refresh(c.read(provider.notifier)),
    invalidate: (c) => c.invalidate(provider),
    listen: (c) => c.listen(provider, (_, _) {}),
    notifier: (c) => c.read(provider.notifier),
    state: (c) {
      final s = c.read(provider);
      return (
        id: s.hasValue ? idOf(s.requireValue) : null,
        error: s.error,
        loading: s.isLoading,
      );
    },
  );

  final String name;
  final Object Function(String id) data;
  final Future<String> Function(ProviderContainer) load;
  final Future<void> Function(ProviderContainer) refresh;
  final void Function(ProviderContainer) invalidate;
  final ProviderSubscription<Object?> Function(ProviderContainer) listen;
  final Object Function(ProviderContainer) notifier;
  final ({String? id, Object? error, bool loading}) Function(ProviderContainer)
  state;
}

final _cases = [
  _Case.of(
    'tripsProvider',
    tripsProvider,
    data: (id) => {
      'items': [
        {
          'id': 1,
          'name': id,
          'legs': [
            {
              'location': 'Tokyo',
              'latitude': 35.68,
              'longitude': 139.69,
              'timezone': 'Asia/Tokyo',
              'start_date': '2027-01-01',
              'end_date': '2027-01-05',
            },
          ],
        },
      ],
    },
    idOf: (trips) => trips.single.name,
    refresh: (n) => n.refresh(),
  ),
  _Case.of(
    'profileProvider',
    profileProvider,
    data: (id) => {'name': id},
    idOf: (p) => p.profile.name,
    refresh: (n) => n.refresh(),
  ),
  _Case.of(
    'styleTasteProfileProvider',
    styleTasteProfileProvider,
    data: (id) => {'status': 'ready', 'summary': id},
    idOf: (t) => t.summary,
    refresh: (n) => n.refresh(),
  ),
  _Case.of(
    'styleProfileProvider',
    styleProfileProvider,
    data: (id) => {
      'items': [
        {'style': id, 'count': 1},
      ],
    },
    idOf: (items) => items.single.rawStyle,
    refresh: (n) => n.refresh(),
  ),
];

/// Answers each account's request with that account's current version
/// (`A1`, then `A2` after [bump]); the version is fixed when the request
/// arrives. [hold] makes an account's next request wait for its release.
class _Backend {
  _Backend(this.data);
  final Object Function(String id) data;
  final _versions = <String, int>{};
  final _holds = <String, Completer<void>>{};
  bool expired = false;

  void bump(String account) =>
      _versions[account] = (_versions[account] ?? 1) + 1;

  void Function() hold(String account) {
    final gate = Completer<void>();
    _holds[account] = gate;
    return gate.complete;
  }

  MockClient client() => MockClient((req) async {
    if (req.url.path.endsWith('/auth/refresh')) {
      return http.Response('{}', 401);
    }
    if (expired) return http.Response('{}', 401);
    final account = req.headers['Authorization']!.replaceFirst(
      'Bearer access-',
      '',
    );
    final id = '$account${_versions[account] ?? 1}';
    final gate = _holds.remove(account);
    if (gate != null) await gate.future;
    return jsonResponse(envelope(data(id)));
  });
}

Future<void> _signIn(String account) async {
  await AuthStorage.clear();
  await AuthStorage.startSession(
    accessToken: 'access-$account',
    refreshToken: 'refresh-$account',
  );
}

void main() {
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
  });

  for (final c in _cases) {
    group(c.name, () {
      late _Backend backend;
      late ProviderContainer container;

      /// A signed in, the provider loaded and listened to, as a page would.
      Future<void> run(Future<void> Function() body) {
        backend = _Backend(c.data);
        return http.runWithClient(() async {
          container = ProviderContainer(retry: (_, _) => null);
          addTearDown(container.dispose);
          final sub = c.listen(container);
          addTearDown(sub.close);
          expect(await c.load(container), 'A1');
          await body();
        }, backend.client);
      }

      /// What the next sign-in does to providers.
      Future<String> signInAndReload(String account) async {
        await _signIn(account);
        c.invalidate(container);
        return c.load(container);
      }

      test('invalidate keeps the same notifier instance (why a generation '
          'is needed rather than ref.mounted)', () {
        return run(() async {
          final before = c.notifier(container);
          expect(await signInAndReload('B'), 'B1');
          expect(identical(c.notifier(container), before), isTrue);
        });
      });

      test("A → B: A's refresh failing late (SessionChangedException) "
          "doesn't replace B's loaded state", () {
        return run(() async {
          final releaseA = backend.hold('A');
          final stale = c.refresh(container);
          await pumpEventQueue();

          expect(await signInAndReload('B'), 'B1');
          releaseA();
          await stale;

          final s = c.state(container);
          expect(s.error, isNull, reason: '$s');
          expect(s.id, 'B1');
        });
      });

      test("an earlier generation's late success doesn't replace the newer "
          'state', () {
        // Across accounts withAuth already turns a late reply into
        // SessionChangedException; a rebuild within one session is how an
        // earlier generation's reply can still succeed.
        return run(() async {
          final releaseOld = backend.hold('A');
          final stale = c.refresh(container);
          await pumpEventQueue();

          backend.bump('A');
          c.invalidate(container);
          expect(await c.load(container), 'A2');
          releaseOld();
          await stale;

          final s = c.state(container);
          expect(s.error, isNull, reason: '$s');
          expect(s.id, 'A2');
        });
      });

      test("A → B → C: neither A's nor B's late refresh replaces C's "
          'state', () {
        return run(() async {
          final releaseA = backend.hold('A');
          final staleA = c.refresh(container);
          await pumpEventQueue();
          expect(await signInAndReload('B'), 'B1');

          final releaseB = backend.hold('B');
          final staleB = c.refresh(container);
          await pumpEventQueue();
          expect(await signInAndReload('C'), 'C1');

          releaseB();
          await staleB;
          releaseA();
          await staleA;

          final s = c.state(container);
          expect(s.error, isNull, reason: '$s');
          expect(s.id, 'C1');
        });
      });

      test('a refresh within one session still updates the state', () {
        return run(() async {
          backend.bump('A');
          await c.refresh(container);

          final s = c.state(container);
          expect(s.error, isNull, reason: '$s');
          expect(s.id, 'A2');
          expect(s.loading, isFalse);
        });
      });

      test("the current session's AuthExpiredException still reaches the "
          'state', () {
        return run(() async {
          backend.expired = true;
          await c.refresh(container);

          expect(c.state(container).error, isA<AuthExpiredException>());
        });
      });
    });
  }
}
