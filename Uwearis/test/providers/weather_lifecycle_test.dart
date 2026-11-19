import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/locale_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

// Async lifecycle audit of weatherProvider. Riverpod 3.3.2 keeps the same
// WeatherNotifier across invalidate / a locale rebuild, and `ref` is always
// the newest build's — so `ref.mounted` after an await is true for a reply
// to an earlier generation too. Skipped tests reproduce a finding; run them
// with --run-skipped.

const _cacheKey = 'cached_weather_v2';

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// `GET /weather`, naming the place after the account that asked (by its
/// access token) and the language its request was told to use. With [hold]
/// replies wait for the test. `PATCH /users/me` (the locale push) succeeds.
class _WeatherBackend {
  int gets = 0;
  bool hold = false;
  final List<Completer<void>> held = [];

  /// The backend's profile locale (set by the app's locale PATCH).
  String profileLocale = 'en';

  late final MockClient client = MockClient((request) async {
    if (request.method == 'PATCH') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      profileLocale = body['locale'] as String? ?? profileLocale;
      return jsonResponse(envelope({'id': 1, 'locale': profileLocale}));
    }
    gets++;
    final account = (request.headers['Authorization'] ?? '').endsWith('token-b')
        ? 'B'
        : 'A';
    final name = '$account-city-$profileLocale';
    if (hold) {
      final gate = Completer<void>();
      held.add(gate);
      await gate.future;
    }
    return jsonResponse(
      envelope({
        'location_name': name,
        'current': {'temperature_c': 20, 'weather_code': 0, 'is_day': true},
        'daily': [
          {'temperature_max_c': 24, 'temperature_min_c': 16, 'weather_code': 0},
        ],
      }),
    );
  });

  Future<void> releaseAll() async {
    hold = false;
    for (final gate in [...held]) {
      gate.complete();
    }
    held.clear();
    await _settle();
  }
}

/// A cached reading for [name], [age] old, fetched under [locale].
String _cacheJson(String name, {required Duration age, String locale = 'en'}) =>
    json.encode(
      WeatherData(
        location: name,
        temp: 20,
        high: 24,
        low: 16,
        condition: 'Clear',
        currentCode: 0,
        weeklyCodes: const [0],
        weeklyHighs: const [24],
        weeklyLows: const [16],
        timestamp: DateTime.now().subtract(age).millisecondsSinceEpoch,
        locationLocale: locale,
      ).toJson(),
    );

void main() {
  late _WeatherBackend backend;
  late ProviderContainer container;

  setUp(() {
    // Device locale is en here; account A's token is "token-a".
    setUpFakeAuth(accessToken: 'token-a');
    backend = _WeatherBackend();
  });

  Future<void> run(Map<String, Object> prefs, Future<void> Function() body) {
    SharedPreferences.setMockInitialValues(prefs);
    return http.runWithClient(() async {
      container = ProviderContainer();
      addTearDown(container.dispose);
      await body();
    }, () => backend.client);
  }

  String? shown() => container.read(weatherProvider).value?.location;

  Future<String?> cachedName() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    return raw == null ? null : (json.decode(raw) as Map)['location'] as String;
  }

  /// Sign-out (clears the cache) then sign-in as account B.
  Future<void> switchToB() async {
    await WeatherNotifier.clearCache();
    setUpFakeAuth(accessToken: 'token-b');
    container.invalidate(weatherProvider);
    await _settle();
  }

  test('Riverpod keeps the same WeatherNotifier across invalidate', () {
    return run({}, () async {
      container.listen(weatherProvider, (_, _) {});
      await _settle();
      final before = container.read(weatherProvider.notifier);
      container.invalidate(weatherProvider);
      await _settle();

      expect(
        identical(container.read(weatherProvider.notifier), before),
        isTrue,
      );
    });
  });

  test('a normal load shows and caches the reading', () {
    return run({}, () async {
      container.listen(weatherProvider, (_, _) {});
      await _settle();

      expect(shown(), 'A-city-en');
      expect(await cachedName(), 'A-city-en');
      expect(backend.gets, 1);
    });
  });

  test('a fresh cache is shown without a request', () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(minutes: 5))},
      () async {
        container.listen(weatherProvider, (_, _) {});
        await _settle();

        expect(shown(), 'Cached');
        expect(backend.gets, 0);
      },
    );
  });

  test('a stale cache is shown, then refreshed in the background', () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        container.listen(weatherProvider, (_, _) {});
        await _settle();

        expect(shown(), 'A-city-en');
        expect(backend.gets, 1);
      },
    );
  });

  test(
    'overlapping refreshIfStale calls in one generation send one request',
    () {
      return run(
        {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
        () async {
          backend.hold = true;
          container.listen(weatherProvider, (_, _) {});
          await _settle(); // the build's own background refresh is in flight
          final notifier = container.read(weatherProvider.notifier);
          unawaited(notifier.refreshIfStale());
          unawaited(notifier.refreshIfStale());
          await _settle();

          expect(backend.gets, 1);
          await backend.releaseAll();
          expect(shown(), 'A-city-en');
        },
      );
    },
  );

  test("W1. a background refresh from account A landing after B signed in "
      "doesn't replace B's weather", () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        backend.hold = true;
        container.listen(weatherProvider, (_, _) {});
        await _settle(); // A's background refresh is in flight
        final aGate = backend.held.single;
        backend.held.clear();

        backend.hold = false;
        await switchToB();
        expect(shown(), 'B-city-en');

        aGate.complete(); // A's reply lands
        await _settle();
        expect(shown(), 'B-city-en');
        expect(await cachedName(), 'B-city-en');
      },
    );
  });

  test("W2. account A's first load landing after sign-out isn't cached for "
      'account B', () {
    return run({}, () async {
      backend.hold = true;
      container.listen(weatherProvider, (_, _) {});
      await _settle(); // A's first load is in flight
      await WeatherNotifier.clearCache(); // A signs out

      await backend.releaseAll(); // A's reply lands after sign-out
      expect(await cachedName(), isNull);

      setUpFakeAuth(accessToken: 'token-b'); // B signs in
      container.invalidate(weatherProvider);
      await _settle();
      expect(shown(), 'B-city-en');
    });
  });

  test('W3. a background refresh started in English landing after a switch to '
      "Chinese doesn't bring the English place name back", () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        backend.hold = true;
        container.listen(weatherProvider, (_, _) {});
        await _settle(); // the English background refresh is in flight
        final enGate = backend.held.single;
        backend.held.clear();

        backend.hold = false;
        await container
            .read(localeProvider.notifier)
            .setLocale(const Locale('zh', 'TW'));
        await _settle();
        expect(shown(), 'A-city-zh-TW');

        enGate.complete();
        await _settle();
        expect(shown(), 'A-city-zh-TW');
        expect(await cachedName(), 'A-city-zh-TW');
      },
    );
  });

  test('W4. a refresh still in flight from the previous generation does not '
      "block the new generation's own refresh", () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        backend.hold = true;
        container.listen(weatherProvider, (_, _) {});
        await _settle(); // A's background refresh is in flight

        // B signs in to a stale cache of its own.
        SharedPreferences.setMockInitialValues({
          _cacheKey: _cacheJson('B-old', age: const Duration(hours: 1)),
        });
        setUpFakeAuth(accessToken: 'token-b');
        container.invalidate(weatherProvider);
        await _settle();

        expect(backend.held, hasLength(2), reason: "B's refresh was sent");
        await backend.releaseAll();
      },
    );
  });

  test('dispose while a background refresh is in flight: no error, and the '
      'late reply changes nothing', () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        backend.hold = true;
        final sub = container.listen(weatherProvider, (_, _) {});
        await _settle();
        sub.close();
        container.dispose();

        await backend.releaseAll();
        expect(await cachedName(), 'Cached');
      },
    );
  });

  test('dispose before the build-scheduled refresh runs: no error, no '
      'request', () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        final sub = container.listen(weatherProvider, (_, _) {});
        await container.read(weatherProvider.future);
        sub.close();
        container.dispose(); // before Future(refreshIfStale) runs
        await _settle();

        expect(backend.gets, 0);
      },
    );
  });

  test("the previous generation's refresh finishing doesn't clear the new "
      "generation's in-flight flag (no duplicate request)", () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        backend.hold = true;
        container.listen(weatherProvider, (_, _) {});
        await _settle(); // A's background refresh (old generation)
        SharedPreferences.setMockInitialValues({
          _cacheKey: _cacheJson('B-old', age: const Duration(hours: 1)),
        });
        setUpFakeAuth(accessToken: 'token-b');
        container.invalidate(weatherProvider);
        await _settle(); // B's own background refresh, also held
        final gates = [...backend.held];
        backend.held.clear();
        expect(gates, hasLength(2));

        gates[0].complete(); // A's finishes first
        await _settle();
        unawaited(container.read(weatherProvider.notifier).refreshIfStale());
        await _settle();
        expect(backend.gets, 2, reason: "B's refresh is still in flight");

        backend.hold = false;
        gates[1].complete();
        await _settle();
        expect(shown(), 'B-city-en');
      },
    );
  });

  test("the previous generation's reply landing before the new one's still "
      'changes nothing', () {
    return run(
      {_cacheKey: _cacheJson('Cached', age: const Duration(hours: 1))},
      () async {
        backend.hold = true;
        container.listen(weatherProvider, (_, _) {});
        await _settle();
        await WeatherNotifier.clearCache();
        setUpFakeAuth(accessToken: 'token-b');
        container.invalidate(weatherProvider);
        await _settle(); // B's first load, held
        final gates = [...backend.held];
        backend.held.clear();

        gates[0].complete(); // A's lands first
        await _settle();
        expect(await cachedName(), isNull);

        backend.hold = false;
        gates[1].complete();
        await _settle();
        expect(shown(), 'B-city-en');
        expect(await cachedName(), 'B-city-en');
      },
    );
  });

  for (final clearFirst in [true, false]) {
    test(
      'a reply and the sign-out clear racing '
      '(${clearFirst ? 'clear' : 'reply'} first) leave no cached reading',
      () {
        return run({}, () async {
          backend.hold = true;
          container.listen(weatherProvider, (_, _) {});
          await _settle(); // A's first load is in flight

          final gates = [...backend.held];
          backend
            ..held.clear()
            ..hold = false;
          if (clearFirst) {
            unawaited(WeatherNotifier.clearCache());
            gates.single.complete();
          } else {
            gates.single.complete();
            unawaited(WeatherNotifier.clearCache());
          }
          await _settle();

          expect(await cachedName(), isNull);
        });
      },
    );
  }

  test('a reply that was already cached before the sign-out is removed by '
      'the clear', () {
    return run({}, () async {
      container.listen(weatherProvider, (_, _) {});
      await _settle();
      expect(await cachedName(), 'A-city-en');

      await WeatherNotifier.clearCache();
      expect(await cachedName(), isNull);
    });
  });
}
