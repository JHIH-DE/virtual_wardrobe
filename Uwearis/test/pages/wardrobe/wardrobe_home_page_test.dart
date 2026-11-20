import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/wardrobe/today_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/wardrobe_home_page.dart';
import 'package:uwearis/features/widgets/common/carousel_dots_indicator.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/mock_http.dart';
import '../../helpers/widget_harness.dart';

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

/// Resolves only after [delay], so a test can see Home before today's
/// outfit has arrived.
class _DelayedDailyOutfitNotifier extends _FakeDailyOutfitNotifier {
  _DelayedDailyOutfitNotifier(super.outfits, {required this.delay});
  final Duration delay;

  @override
  Future<List<Outfit>> build() async {
    await Future<void>.delayed(delay);
    return _outfits;
  }
}

/// [refresh] stays loading for [delay] before showing [next].
class _SlowRefreshDailyOutfitNotifier extends _FakeDailyOutfitNotifier {
  _SlowRefreshDailyOutfitNotifier(super.outfits, {required this.next});
  final List<Outfit> next;
  static const delay = Duration(milliseconds: 100);

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = const AsyncLoading();
    await Future<void>.delayed(delay);
    state = AsyncData(next);
  }
}

/// Fails its first load, then succeeds.
class _FailOnceGarmentsNotifier extends GarmentsNotifier {
  static int builds = 0;

  @override
  Future<List<Garment>> build() async {
    if (builds++ == 0) throw Exception('first load failed');
    return const [_topGarment, _bottomGarment, _shoesGarment];
  }
}

class _DelayedProfileNotifier extends _FakeProfileNotifier {
  _DelayedProfileNotifier({required this.delay});
  final Duration delay;

  @override
  Future<ProfileData> build() async {
    await Future<void>.delayed(delay);
    return data;
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

  static int staleChecks = 0;

  @override
  Future<void> refreshIfStale() async => staleChecks++;
}

const _topGarment = Garment(
  id: 1,
  name: 'Test Top',
  category: GarmentCategory.top,
  subCategory: 'T-Shirt',
  uploadUrl: '',
  objectName: '',
);
const _bottomGarment = Garment(
  id: 2,
  name: 'Test Bottom',
  category: GarmentCategory.bottom,
  subCategory: 'Jeans',
  uploadUrl: '',
  objectName: '',
);
const _shoesGarment = Garment(
  id: 3,
  name: 'Test Shoes',
  category: GarmentCategory.shoes,
  subCategory: 'Sneakers',
  uploadUrl: '',
  objectName: '',
);

/// Defaults to a Top/Bottom/Shoes closet, so tests land on normal Home
/// rather than Getting Started.
class _FakeGarmentsNotifier extends GarmentsNotifier {
  _FakeGarmentsNotifier({this.garments = _fullCloset});

  static const _fullCloset = [_topGarment, _bottomGarment, _shoesGarment];

  final List<Garment> garments;

  @override
  Future<List<Garment>> build() async => garments;
}

/// Resolves only after [delay], so a test can observe an in-flight
/// `ref.invalidate` refetch.
class _DelayedGarmentsNotifier extends GarmentsNotifier {
  _DelayedGarmentsNotifier(
    this.garments, {
    this.delay = const Duration(milliseconds: 100),
  });

  final List<Garment> garments;
  final Duration delay;

  @override
  Future<List<Garment>> build() async {
    await Future<void>.delayed(delay);
    return garments;
  }
}

/// Defaults to a fully set-up profile.
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier({ProfileData? data}) : data = data ?? _complete;

  static final _complete = ProfileData(
    profile: UserProfile(
      name: 'Test User',
      gender: 'Prefer not to say',
      location: 'Test City',
      birthDate: DateTime(1995, 1, 1),
    ),
    bodyRefUrl: 'https://example.com/body.jpg',
    faceRefUrl: 'https://example.com/face.jpg',
  );

  final ProfileData data;

  @override
  Future<ProfileData> build() async => data;
}

/// Defaults to one created outfit.
class _FakeOutfitsNotifier extends OutfitsNotifier {
  _FakeOutfitsNotifier({List<Outfit>? outfits})
    : outfits = outfits ?? _oneOutfit;

  static final _oneOutfit = [
    Outfit(id: 100, imageUrl: 'https://example.com/my-outfit.jpg'),
  ];

  List<Outfit> outfits;

  @override
  Future<List<Outfit>> build() async => outfits;

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(outfits);
  }
}

/// Defaults to no trips.
class _FakeTripsNotifier extends TripsNotifier {
  _FakeTripsNotifier({this.trips = const []});

  final List<Trip> trips;

  @override
  Future<List<Trip>> build() async => trips;
}

final _testTrip = Trip(
  id: 't1',
  name: 'Test Trip',
  activities: const [],
  legs: [
    TripLeg(
      location: LocationResult(
        name: 'Tokyo',
        latitude: 35.6,
        longitude: 139.7,
        timezone: 'Asia/Tokyo',
      ),
      dateRange: DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 5),
      ),
    ),
  ],
);

/// Lets a route push/pop transition run to completion — Home keeps an
/// animation running, so pumpAndSettle never settles.
Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  List<Override> overridesWith(
    _FakeDailyOutfitNotifier dailyOutfit, {
    GarmentsNotifier? garments,
    ProfileNotifier? profile,
    _FakeOutfitsNotifier? outfits,
    _FakeTripsNotifier? trips,
  }) => [
    dailyOutfitProvider.overrideWith(() => dailyOutfit),
    weatherProvider.overrideWith(_FakeWeatherNotifier.new),
    garmentsProvider.overrideWith(() => garments ?? _FakeGarmentsNotifier()),
    profileProvider.overrideWith(() => profile ?? _FakeProfileNotifier()),
    outfitsProvider.overrideWith(() => outfits ?? _FakeOutfitsNotifier()),
    tripsProvider.overrideWith(() => trips ?? _FakeTripsNotifier()),
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
        WardrobeHomePage(now: () => now),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(dailyOutfit.refreshCount, 0);
      // Header: the weather illustration, and a thermometer on the range.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/images/weather/clear-day.svg',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.thermostat_rounded), findsOneWidget);
      final badge = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(SvgPicture),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (badge.decoration! as BoxDecoration).color,
        AppColors.weatherBadgeDay,
      );

      now = DateTime(2026, 9, 18, 0, 5);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
        WardrobeHomePage(now: () => now),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(dailyOutfit.refreshCount, 0);

      // Wall clock jumps past midnight (like a manual date change), then
      // one poll tick elapses.
      now = DateTime(2026, 9, 18, 0, 0, 5);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();

      expect(find.text('Friday, Sep 18'), findsOneWidget);
      expect(dailyOutfit.refreshCount, 1);
    },
  );

  testWidgets('resuming on the same day does not re-trigger a refresh', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 17, 10);
    final dailyOutfit = _FakeDailyOutfitNotifier([
      Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
    ]);

    await pumpApp(
      tester,
      WardrobeHomePage(now: () => now),
      overrides: overridesWith(dailyOutfit),
    );
    await tester.pump();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(dailyOutfit.refreshCount, 0);
  });

  testWidgets(
    'weather is checked for staleness on resume and on every poll tick',
    (tester) async {
      _FakeWeatherNotifier.staleChecks = 0;
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(_FakeDailyOutfitNotifier(const [])),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_FakeWeatherNotifier.staleChecks, 1);

      await tester.pump(const Duration(minutes: 1));
      expect(_FakeWeatherNotifier.staleChecks, 2);
    },
  );

  testWidgets(
    'a brand-new account (no reference photos, empty closet, no outfits) '
    'sees Getting Started instead of the normal Home content',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          garments: _FakeGarmentsNotifier(garments: const []),
          outfits: _FakeOutfitsNotifier(outfits: const []),
          profile: _FakeProfileNotifier(
            data: const ProfileData(profile: UserProfile()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsNothing);
      expect(find.text('Welcome to Uwearis'), findsOneWidget);
      expect(find.text('My Virtual Model'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text("Today's Outfit"), findsNothing);
      expect(find.text('Recently Added'), findsNothing);
    },
  );

  testWidgets(
    'reference photos done but an empty closet shows My Virtual Model '
    'checked and the CTA already reading Next (About You is done)',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          garments: _FakeGarmentsNotifier(garments: const []),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('My Virtual Model'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
    },
  );

  testWidgets(
    'a closet covering only two of the three required categories (Top + '
    'Bottom, no Shoes) still keeps the CTA reading Next',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          garments: _FakeGarmentsNotifier(
            garments: const [_topGarment, _bottomGarment],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Next'), findsOneWidget);
    },
  );

  testWidgets(
    'photos and closet done but no outfit created yet still keeps the CTA '
    'reading Next, not normal Home',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          outfits: _FakeOutfitsNotifier(outfits: const []),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsNothing);
      expect(find.text('Welcome to Uwearis'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Create Outfit'), findsOneWidget);
      expect(find.text("Today's Outfit"), findsNothing);
      expect(find.text('Recently Added'), findsNothing);
    },
  );

  testWidgets(
    'a fully set-up returning user (photos + closet + a created outfit) '
    'goes straight to normal Home, never Getting Started',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ]);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(find.text('Welcome to Uwearis'), findsNothing);
    },
  );

  testWidgets(
    'an established user (closet + a created outfit already there) who '
    'deletes both reference photos stays on normal Home — an established '
    'user is never sent back through the whole Getting Started flow just '
    'for a missing photo',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ]);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          profile: _FakeProfileNotifier(
            data: const ProfileData(profile: UserProfile()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(find.text('Welcome to Uwearis'), findsNothing);
    },
  );

  testWidgets(
    'an established user via trip data alone (no closet/outfit yet, both '
    'reference photos also missing) still goes through Getting Started, '
    'starting from the profile-photo step as usual',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          garments: _FakeGarmentsNotifier(garments: const []),
          outfits: _FakeOutfitsNotifier(outfits: const []),
          trips: _FakeTripsNotifier(trips: [_testTrip]),
          profile: _FakeProfileNotifier(
            data: const ProfileData(profile: UserProfile()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // A trip alone doesn't satisfy the closet requirement, so Getting
      // Started still shows, from the top.
      expect(find.text('Welcome to Uwearis'), findsOneWidget);
      expect(find.text('My Virtual Model'), findsOneWidget);
    },
  );

  testWidgets(
    'an established user with a full closet and a planned trip, but who has '
    'never created a standalone "My Outfits" look, still sees today\'s '
    'daily-generated outfit on normal Home instead of being stuck on '
    'Getting Started — outfitsProvider only ever holds standalone looks '
    '(daily/trip outfits are filtered out server-side), so it must not be '
    'the only signal that gates an already-established user',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ]);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          outfits: _FakeOutfitsNotifier(outfits: const []),
          trips: _FakeTripsNotifier(trips: [_testTrip]),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Welcome to Uwearis'), findsNothing);
      expect(find.text("Today's Outfit"), findsOneWidget);
    },
  );

  testWidgets(
    'a fully set-up user with no outfit generated for today specifically '
    '(but has created outfits before) sees their newest "My Outfits" look '
    'in that slot instead — not a "first look" CTA (not their first outfit '
    'any more), and not a blank slot either (falls back to something real '
    'rather than nothing)',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(find.text('No outfit image yet'), findsNothing);
      expect(find.text("Today's Outfit"), findsNothing);
      expect(find.text('Your Latest Outfit'), findsOneWidget);
    },
  );

  testWidgets('a fully set-up user with no outfit generated for today AND no '
      '"My Outfits" look to fall back to sees nothing in that slot at all '
      '(established here via trip data alone, same as the daily-outfit-'
      'present case above)', (tester) async {
    final dailyOutfit = _FakeDailyOutfitNotifier(const []);
    await pumpApp(
      tester,
      WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
      overrides: overridesWith(
        dailyOutfit,
        outfits: _FakeOutfitsNotifier(outfits: const []),
        trips: _FakeTripsNotifier(trips: [_testTrip]),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome to Uwearis'), findsNothing);
    expect(find.text('No outfit image yet'), findsNothing);
    expect(find.text("Today's Outfit"), findsNothing);
    expect(find.text('Your Latest Outfit'), findsNothing);
  });

  testWidgets(
    'adding the last missing closet category (Shoes) while Home stays '
    'mounted (IndexedStack) flips Getting Started straight to normal Home '
    'on its own, via the shared garmentsProvider — no extra refresh/'
    'didPopNext plumbing needed',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          garments: _FakeGarmentsNotifier(
            garments: const [_topGarment, _bottomGarment],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Next'), findsOneWidget);

      // Simulates GarmentUploadHelper's onAdded callback.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WardrobeHomePage)),
      );
      container.read(garmentsProvider.notifier).addGarment(_shoesGarment);
      await tester.pump();

      expect(find.text('Next'), findsNothing);
      expect(find.text('Welcome to Uwearis'), findsNothing);
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
    },
  );

  testWidgets(
    'creating the first outfit while Home stays mounted (IndexedStack) '
    'flips Getting Started straight to normal Home on its own, via the '
    'shared outfitsProvider',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      final outfits = _FakeOutfitsNotifier(outfits: const []);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(dailyOutfit, outfits: outfits),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Create Outfit'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Simulates the post-save outfitsProvider refresh.
      outfits.outfits = [
        Outfit(id: 200, imageUrl: 'https://example.com/new-outfit.jpg'),
      ];
      await outfits.refresh();
      await tester.pump();

      expect(find.text('Create Outfit'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Welcome to Uwearis'), findsNothing);
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
    },
  );

  testWidgets('regression: a sign-in (invalidateSignedInProviders, then a '
      'new Home) must not flash the previous account\'s stale Home content '
      'while the new account\'s fetch is still in flight', (tester) async {
    final dailyOutfit = _FakeDailyOutfitNotifier([
      Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
    ]);
    const delay = Duration(milliseconds: 50);
    await pumpApp(
      tester,
      WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
      overrides: overridesWith(
        dailyOutfit,
        garments: _DelayedGarmentsNotifier(const [
          _topGarment,
          _bottomGarment,
          _shoesGarment,
        ], delay: delay),
      ),
    );
    await tester.pump();
    // A zero-duration pump() never fires a Future.delayed.
    await tester.pump(delay);
    expect(find.text('Thursday, Sep 17'), findsOneWidget);

    // As in the app: the signed-in shell is gone before the next login,
    // which invalidates the providers and mounts a new Home. The
    // AsyncLoading still carries account A's value.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await _pumpRoute(tester);
    expect(find.byType(WardrobeHomePage), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator)),
    );
    container.invalidate(garmentsProvider);
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // Mid-refetch: must not fall through to A's stale value.
    expect(find.text('Thursday, Sep 17'), findsNothing);
    expect(find.text('Welcome to Uwearis'), findsNothing);

    await tester.pump(delay);
    await _pumpRoute(tester);
    expect(find.text('Thursday, Sep 17'), findsOneWidget);
  });

  testWidgets('refreshes while Home stays mounted keep showing its content: no '
      'blank page, and the outfit carousel is not swapped for a spinner', (
    tester,
  ) async {
    const delay = Duration(milliseconds: 50);
    final dailyOutfit = _FakeDailyOutfitNotifier([
      Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
    ]);
    await pumpApp(
      tester,
      WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
      overrides: overridesWith(
        dailyOutfit,
        garments: _DelayedGarmentsNotifier(const [
          _topGarment,
          _bottomGarment,
          _shoesGarment,
        ], delay: delay),
      ),
    );
    await tester.pump();
    await tester.pump(delay);
    expect(find.byType(PageView), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WardrobeHomePage)),
    );
    container.invalidate(garmentsProvider);
    dailyOutfit.state = const AsyncLoading();
    await tester.pump();

    expect(find.text('Thursday, Sep 17'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    await tester.pump(delay);
  });

  testWidgets(
    "tapping today's outfit opens Today's Outfit on that option, and Home's "
    'carousel follows the swipes made there',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, name: 'Office', imageUrl: 'https://example.com/1.jpg'),
        Outfit(id: 2, name: 'Weekend', imageUrl: 'https://example.com/2.jpg'),
      ]);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(PageView));
      await _pumpRoute(tester);

      expect(find.byType(TodayOutfitPage), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);

      await tester.drag(
        find.descendant(
          of: find.byType(TodayOutfitPage),
          matching: find.byType(PageView),
        ),
        const Offset(-800, 0),
      );
      await _pumpRoute(tester);
      expect(find.text('Weekend'), findsOneWidget);

      await tester.pageBack();
      await _pumpRoute(tester);

      expect(find.byType(TodayOutfitPage), findsNothing);
      expect(
        tester
            .widget<CarouselDotsIndicator>(find.byType(CarouselDotsIndicator))
            .currentIndex,
        1,
      );
    },
  );

  testWidgets(
    'an established user sees Home as soon as the closet and outfits are '
    'in, with today\'s outfit filling in later; profile is not waited on',
    (tester) async {
      const delay = Duration(milliseconds: 100);
      final dailyOutfit = _DelayedDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ], delay: delay);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          profile: _DelayedProfileNotifier(delay: delay),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(find.text('Recently Added'), findsOneWidget);
      expect(find.text("Today's Outfit"), findsOneWidget);
      expect(find.byType(PageView), findsNothing);

      await tester.pump(delay);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Welcome to Uwearis'), findsNothing);
    },
  );

  testWidgets(
    "after midnight, yesterday's plan is not shown as today's while the "
    'new day loads',
    (tester) async {
      var now = DateTime(2026, 9, 17, 23, 59, 50);
      final dailyOutfit = _SlowRefreshDailyOutfitNotifier(
        [Outfit(id: 1, imageUrl: 'https://example.com/yesterday.jpg')],
        next: [Outfit(id: 2, imageUrl: 'https://example.com/today.jpg')],
      );
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => now),
        overrides: overridesWith(dailyOutfit),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);

      now = DateTime(2026, 9, 18, 0, 0, 5);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();

      expect(dailyOutfit.refreshCount, 1);
      expect(find.text('Friday, Sep 18'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);

      await tester.pump(_SlowRefreshDailyOutfitNotifier.delay);
      expect(find.byType(PageView), findsOneWidget);
    },
  );

  testWidgets(
    'a failed first closet load shows Retry rather than Getting Started '
    'with an empty closet, and Retry brings Home back',
    (tester) async {
      _FailOnceGarmentsNotifier.builds = 0;
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          _FakeDailyOutfitNotifier(const []),
          garments: _FailOnceGarmentsNotifier(),
        ),
        retry: (_, _) => null,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Welcome to Uwearis'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
    },
  );

  // F4: the latest-outfit fallback card's optimistic favorite racing an
  // outfitsProvider refresh that read the server before the PATCH committed.
  group('fallback favorite vs. an outfits refresh', () {
    late bool serverFavorite;
    late bool holdList;
    late bool holdPatch;
    late bool patchFails;
    late http.Response? patchReply;
    late List<Completer<void>> listGates;
    late List<Completer<void>> patchGates;
    late ProviderContainer container;

    Map<String, dynamic> outfitJson(bool fav) => {
      'outfit_id': 100,
      'group_id': 100,
      'group_type': 'general',
      'status': 'completed',
      'garment_ids': <int>[],
      'result_image_url': 'https://example.com/my-outfit.jpg',
      'season': <String>[],
      'style': <String>[],
      'is_favorite': fav,
    };

    setUp(() {
      setUpFakeAuth();
      serverFavorite = false;
      holdList = false;
      holdPatch = false;
      patchFails = false;
      patchReply = null;
      listGates = [];
      patchGates = [];
    });

    MockClient backend() => MockClient((request) async {
      if (request.method == 'PATCH') {
        final value =
            (jsonDecode(request.body) as Map<String, dynamic>)['is_favorite']
                as bool;
        if (holdPatch) {
          final gate = Completer<void>();
          patchGates.add(gate);
          await gate.future;
        }
        if (patchReply != null) return patchReply!;
        if (patchFails) return jsonResponse({'success': false}, status: 500);
        serverFavorite = value;
        return jsonResponse(envelope(outfitJson(value)));
      }
      final snapshot = outfitJson(serverFavorite);
      if (holdList) {
        final gate = Completer<void>();
        listGates.add(gate);
        await gate.future;
      }
      return jsonResponse(
        envelope({
          'items': [
            {
              'group_id': 100,
              'name': null,
              'cover_outfit_id': null,
              'outfits': [snapshot],
            },
          ],
          'total': 1,
          'page': 1,
        }),
      );
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    Future<void> release(
      WidgetTester tester,
      List<Completer<void>> gates,
    ) async {
      for (final gate in [...gates]) {
        gate.complete();
      }
      gates.clear();
      await settle(tester);
    }

    // The real OutfitsNotifier (its refresh goes through the guard).
    Future<void> openHome(WidgetTester tester) async {
      // Tall enough that the fallback card's heart is on screen.
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: [
          dailyOutfitProvider.overrideWith(
            () => _FakeDailyOutfitNotifier(const []),
          ),
          weatherProvider.overrideWith(_FakeWeatherNotifier.new),
          garmentsProvider.overrideWith(_FakeGarmentsNotifier.new),
          profileProvider.overrideWith(_FakeProfileNotifier.new),
          tripsProvider.overrideWith(_FakeTripsNotifier.new),
        ],
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(WardrobeHomePage)),
      );
      await settle(tester);
    }

    bool? providerFavorite() =>
        container.read(outfitsProvider).value?.single.isFavorite;

    testWidgets('favorite → stale refresh answers → PATCH succeeds: Outfits '
        'ends favorited', (tester) async {
      await http.runWithClient(() async {
        await openHome(tester);
        holdPatch = true;
        await tester.tap(find.byIcon(Icons.favorite_border));
        await settle(tester);
        holdList = true;
        final refresh = container.read(outfitsProvider.notifier).refresh();
        await settle(tester);

        await release(tester, listGates); // stale: not favorite
        await refresh;
        await release(tester, patchGates); // PATCH commits

        expect(providerFavorite(), isTrue);
      }, backend);
    });

    testWidgets("a failed PATCH's rollback doesn't undo a newer favorite "
        'written meanwhile (Outfit Details)', (tester) async {
      await http.runWithClient(() async {
        await openHome(tester);
        holdPatch = true;
        patchFails = true;
        await tester.tap(find.byIcon(Icons.favorite_border));
        await settle(tester);

        container
            .read(outfitsProvider.notifier)
            .updateOutfitFavorite(100, isFavorite: true);
        await release(tester, patchGates); // ours fails

        expect(providerFavorite(), isTrue);
        await tester.tap(find.text('OK'));
        await settle(tester);
      }, backend);
    });
    // Finding #1 (A1-b): the heart's reply landing after its session ended.
    group('a reply after the session ended', () {
      final failed = find.text('Failed to update favorite');
      final sessionExpired = find.text('Session Expired');

      BuildContext homeContext(WidgetTester tester) =>
          tester.element(find.byType(WardrobeHomePage));

      Future<void> startFavorite(WidgetTester tester) async {
        await openHome(tester);
        holdPatch = true;
        await tester.tap(find.byIcon(Icons.favorite_border));
        await settle(tester);
        expect(providerFavorite(), isTrue, reason: 'optimistic');
        expect(patchGates, hasLength(1));
      }

      Future<void> closeDialogs(WidgetTester tester) async {
        for (var i = 0; i < 4; i++) {
          final buttons = find.byKey(AppDialog.dismissButtonKey);
          if (buttons.evaluate().isEmpty) break;
          await tester.tap(buttons.last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        while (tester.takeException() != null) {}
      }

      Future<void> signOutTo(WidgetTester tester, Widget page) async {
        final navigator = Navigator.of(homeContext(tester));
        await clearSignedInSession();
        unawaited(
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => page),
            (_) => false,
          ),
        );
      }

      testWidgets('session expired meanwhile: no error over Session Expired, '
          'and the heart is rolled back', (tester) async {
        await http.runWithClient(() async {
          await startFavorite(tester);
          unawaited(AuthExpiredHandler.handle(homeContext(tester)));
          await settle(tester);
          expect(sessionExpired, findsOneWidget);

          await release(tester, patchGates);
          await tester.pump(const Duration(milliseconds: 500));

          final shown = {
            'error': failed.evaluate().length,
            'sessionExpired': sessionExpired.evaluate().length,
            'heart': find.byIcon(Icons.favorite_border).evaluate().length,
            'providerFavorite': providerFavorite(),
          };
          await closeDialogs(tester);
          expect(shown, {
            'error': 0,
            'sessionExpired': 1,
            'heart': 1,
            'providerFavorite': false,
          });
        }, backend);
      });

      testWidgets('sign-out meanwhile: no error over the login page', (
        tester,
      ) async {
        await http.runWithClient(() async {
          await startFavorite(tester);
          await signOutTo(tester, const LoginPage());
          await tester.pump();
          await release(tester, patchGates);
          await tester.pump(const Duration(seconds: 1));
          while (tester.takeException() != null) {}

          final shown = {
            'error': failed.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'login': 1});
        }, backend);
      });

      testWidgets('a reply after Home is gone touches nothing', (tester) async {
        await http.runWithClient(() async {
          await startFavorite(tester);
          await signOutTo(tester, const Scaffold(body: Text('Signed out')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await release(tester, patchGates);
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);
          expect(find.text('Signed out'), findsOneWidget);
          expect(find.byType(AppDialog), findsNothing);
        }, backend);
      });

      testWidgets("the same session's 500 still says so", (tester) async {
        await http.runWithClient(() async {
          await startFavorite(tester);
          patchFails = true;
          await release(tester, patchGates);

          final shown = failed.evaluate().length;
          await closeDialogs(tester);
          expect(shown, 1);
          expect(providerFavorite(), isFalse);
        }, backend);
      });

      testWidgets("the same session's own expiry still goes to Session "
          'Expired', (tester) async {
        await http.runWithClient(() async {
          await startFavorite(tester);
          patchReply = http.Response('{}', 401);
          await release(tester, patchGates);
          await tester.pump(const Duration(milliseconds: 500));

          final shown = {
            'error': failed.evaluate().length,
            'sessionExpired': sessionExpired.evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'sessionExpired': 1});
        }, backend);
      });
    });
  });
}
