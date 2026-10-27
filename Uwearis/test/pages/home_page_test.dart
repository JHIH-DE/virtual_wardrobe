import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/home_page.dart';
import 'package:uwearis/features/pages/today_outfit_page.dart';
import 'package:uwearis/features/widgets/common/carousel_dots_indicator.dart';

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
    _FakeProfileNotifier? profile,
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
        HomePage(now: () => now),
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
        HomePage(now: () => now),
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
      HomePage(now: () => now),
      overrides: overridesWith(dailyOutfit),
    );
    await tester.pump();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(dailyOutfit.refreshCount, 0);
  });

  testWidgets(
    'a brand-new account (no reference photos, empty closet, no outfits) '
    'sees Getting Started instead of the normal Home content',
    (tester) async {
      final dailyOutfit = _FakeDailyOutfitNotifier(const []);
      await pumpApp(
        tester,
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
      HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
        tester.element(find.byType(HomePage)),
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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

  testWidgets('regression: ref.invalidate (as login does via '
      'invalidateSignedInProviders) must not flash the previous account\'s '
      'stale Home content while the new account\'s fetch is still in flight', (
    tester,
  ) async {
    final dailyOutfit = _FakeDailyOutfitNotifier([
      Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
    ]);
    const delay = Duration(milliseconds: 50);
    await pumpApp(
      tester,
      HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
    expect(find.text('Welcome to Uwearis'), findsNothing);

    // What invalidateSignedInProviders does on login: the AsyncLoading
    // still carries account A's value via copyWithPrevious.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container.invalidate(garmentsProvider);
    await tester.pump();

    // Mid-refetch: must not fall through to A's stale value.
    expect(find.text('Thursday, Sep 17'), findsNothing);
    expect(find.text('Welcome to Uwearis'), findsNothing);

    await tester.pump(delay);
    expect(find.text('Thursday, Sep 17'), findsOneWidget);
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
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
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
}
