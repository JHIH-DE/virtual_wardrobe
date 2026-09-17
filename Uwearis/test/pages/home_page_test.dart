import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/home_page.dart';

import '../helpers/widget_harness.dart';

class _FakeDailyOutfitNotifier extends DailyOutfitNotifier {
  _FakeDailyOutfitNotifier(this._outfits);
  final List<Outfit> _outfits;
  int refreshCount = 0;

  @override
  Future<List<Outfit>> build() async => _outfits;

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = const AsyncLoading();
    state = AsyncData(_outfits);
  }
}

class _FakeWeatherNotifier extends WeatherNotifier {
  @override
  Future<WeatherData> build() async => WeatherData(
    location: 'Test City',
    temp: 20,
    high: 22,
    low: 18,
    condition: 'Clear',
    weeklyCodes: const [],
    weeklyHighs: const [],
    weeklyLows: const [],
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );
}

class _FakeGarmentsNotifier extends GarmentsNotifier {
  @override
  Future<List<Garment>> build() async => const [];
}

class _FakeTripsNotifier extends TripsNotifier {
  @override
  Future<List<Trip>> build() async => const [];
}

void main() {
  List<Override> overridesWith(_FakeDailyOutfitNotifier dailyOutfit) => [
    dailyOutfitProvider.overrideWith(() => dailyOutfit),
    weatherProvider.overrideWith(_FakeWeatherNotifier.new),
    garmentsProvider.overrideWith(_FakeGarmentsNotifier.new),
    tripsProvider.overrideWith(_FakeTripsNotifier.new),
  ];

  testWidgets(
    'resuming the app on a new day refreshes the header date and re-fetches '
    'the daily outfit',
    (tester) async {
      var now = DateTime(2026, 9, 17, 10);
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ]);

      await pumpApp(
        tester,
        HomePage(now: () => now),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(dailyOutfit.refreshCount, 0);

      // The calendar day rolls over while the app is still running, then
      // the OS brings it back to the foreground.
      now = DateTime(2026, 9, 18, 0, 5);
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Friday, Sep 18'), findsOneWidget);
      expect(dailyOutfit.refreshCount, 1);
    },
  );

  testWidgets(
    'the daily outfit refreshes automatically once the periodic date-check '
    'poll notices a new day, even if the app stays in the foreground the '
    'whole time (no lifecycle event fires)',
    (tester) async {
      var now = DateTime(2026, 9, 17, 23, 59, 50);
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ]);

      await pumpApp(
        tester,
        HomePage(now: () => now),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(dailyOutfit.refreshCount, 0);

      // The poll ticks every minute (see _dateCheckInterval) — advance past
      // one tick, with the wall clock (widget._now) already past midnight
      // by then, exactly like a device whose date was changed by hand
      // rather than by real elapsed time.
      now = DateTime(2026, 9, 18, 0, 0, 5);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();

      expect(find.text('Friday, Sep 18'), findsOneWidget);
      expect(dailyOutfit.refreshCount, 1);
    },
  );

  testWidgets(
    'resuming on the same day does not re-trigger a refresh',
    (tester) async {
      final now = DateTime(2026, 9, 17, 10);
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ]);

      await pumpApp(
        tester,
        HomePage(now: () => now),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      // Still resumed, still the same day — e.g. an unrelated lifecycle
      // ping, or briefly switching to another app and straight back.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();

      expect(dailyOutfit.refreshCount, 0);
    },
  );
}
