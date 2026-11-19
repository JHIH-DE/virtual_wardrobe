import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/garment_outfits_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/outfit.dart';

import '../helpers/fake_auth.dart';

const _weatherCacheKey = 'cached_weather_v2';

class _CountingWeatherNotifier extends WeatherNotifier {
  _CountingWeatherNotifier(this.onBuild);

  final VoidCallback onBuild;

  @override
  Future<WeatherData> build() async {
    onBuild();
    return WeatherData(
      location: 'Previous account city',
      temp: 20,
      high: 22,
      low: 18,
      condition: 'Clear',
      weeklyCodes: const [0],
      weeklyHighs: const [22],
      weeklyLows: const [18],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

Future<BuildContext> _pumpScope(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return capturedContext;
}

void main() {
  testWidgets(
    'invalidateSignedInProviders runs without throwing when none of the '
    "per-user providers it invalidates have been read yet — the actual "
    "effect of container.invalidate on an already-mounted, still-watched "
    "provider is covered by wardrobe_home_page_test.dart's own regression test",
    (tester) async {
      final context = await _pumpScope(tester);

      expect(() => invalidateSignedInProviders(context), returnsNormally);
    },
  );

  group('account switch', () {
    test('clearSignedInSession removes the cached weather, whose place '
        "name may be the previous account's profile location", () async {
      setUpFakeAuth();
      SharedPreferences.setMockInitialValues({
        _weatherCacheKey: '{"location":"Previous account city"}',
      });

      await clearSignedInSession();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(_weatherCacheKey), isFalse);
    });

    testWidgets('invalidateSignedInProviders rebuilds weatherProvider, so '
        "the next account doesn't see the previous one's reading", (
      tester,
    ) async {
      var builds = 0;
      final context = await _pumpScope(
        tester,
        overrides: [
          weatherProvider.overrideWith(
            () => _CountingWeatherNotifier(() => builds++),
          ),
        ],
      );
      final container = ProviderScope.containerOf(context, listen: false);
      final sub = container.listen(weatherProvider, (_, _) {});
      addTearDown(sub.close);
      await tester.pump();
      expect(builds, 1);

      invalidateSignedInProviders(context);
      await tester.pump();

      expect(builds, 2);
    });

    testWidgets('invalidateSignedInProviders resets garmentOutfitsProvider', (
      tester,
    ) async {
      var fetches = 0;
      final context = await _pumpScope(
        tester,
        overrides: [
          garmentOutfitsProvider.overrideWith((ref, garmentId) async {
            fetches++;
            return const <Outfit>[];
          }),
        ],
      );
      final container = ProviderScope.containerOf(context, listen: false);
      final sub = container.listen(garmentOutfitsProvider(7), (_, _) {});
      addTearDown(sub.close);
      await tester.pump();
      expect(fetches, 1);

      invalidateSignedInProviders(context);
      await tester.pump();

      expect(fetches, 2);
    });
  });

  group('isSettledAuthExpiry', () {
    test(
      "a provider rebuilding after an invalidate still carries the last "
      "build's AuthExpiredException while loading — not a new expiry",
      () async {
        var builds = 0;
        final next = Completer<int>();
        final provider = FutureProvider<int>((ref) {
          if (builds++ == 0) throw AuthExpiredException();
          return next.future;
        });
        final container = ProviderContainer(retry: (_, _) => null);
        addTearDown(container.dispose);
        final sub = container.listen(provider, (_, _) {});
        addTearDown(sub.close);
        await Future<void>.delayed(Duration.zero);
        expect(isSettledAuthExpiry(container.read(provider)), isTrue);

        container.invalidate(provider);
        final rebuilding = container.read(provider);
        expect(rebuilding.isLoading, isTrue);
        expect(rebuilding.error, isA<AuthExpiredException>());
        expect(isSettledAuthExpiry(rebuilding), isFalse);

        next.completeError(AuthExpiredException());
        await Future<void>.delayed(Duration.zero);
        expect(isSettledAuthExpiry(container.read(provider)), isTrue);
      },
    );

    test('data, loading and other errors are not auth expiry', () {
      expect(isSettledAuthExpiry(const AsyncData(1)), isFalse);
      expect(isSettledAuthExpiry(const AsyncLoading<int>()), isFalse);
      expect(
        isSettledAuthExpiry(
          AsyncError<int>(Exception('500'), StackTrace.empty),
        ),
        isFalse,
      );
      expect(
        isSettledAuthExpiry(
          AsyncError<int>(AuthExpiredException(), StackTrace.empty),
        ),
        isTrue,
      );
    });
  });
}
