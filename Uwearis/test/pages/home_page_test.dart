import 'package:flutter/material.dart';
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

/// A closet covering Top/Bottom/Shoes by default — Getting Started's closet
/// step requires one active garment in each of those three categories (see
/// home_page.dart's `_isGettingStarted`/`_hasRequiredCloset`), and most of
/// this file's tests exercise the normal-home path, not Getting Started.
class _FakeGarmentsNotifier extends GarmentsNotifier {
  _FakeGarmentsNotifier({this.garments = _fullCloset});

  static const _fullCloset = [_topGarment, _bottomGarment, _shoesGarment];

  final List<Garment> garments;

  @override
  Future<List<Garment>> build() async => garments;
}

/// Same contract as [_FakeGarmentsNotifier], but `build()` doesn't resolve
/// until [delay] has elapsed — lets a test observe the in-between state of
/// a `ref.invalidate`-triggered refetch (see the regression test below)
/// rather than it settling within a single `pump()`.
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

/// A fully set-up profile (both AI Try-On reference photos present) by
/// default — see [_FakeGarmentsNotifier]'s own doc.
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier({this.data = _complete});

  static const _complete = ProfileData(
    profile: UserProfile(name: 'Test User'),
    bodyRefUrl: 'https://example.com/body.jpg',
    faceRefUrl: 'https://example.com/face.jpg',
  );

  final ProfileData data;

  @override
  Future<ProfileData> build() async => data;
}

/// One already-created outfit by default ("My Outfits" is non-empty — see
/// [_FakeGarmentsNotifier]'s own doc; this is the 4th, final Getting
/// Started condition alongside profile photos + closet).
class _FakeOutfitsNotifier extends OutfitsNotifier {
  _FakeOutfitsNotifier({List<Outfit>? outfits}) : outfits = outfits ?? _oneOutfit;

  static final _oneOutfit = [
    Outfit(id: 100, imageUrl: 'https://example.com/my-outfit.jpg'),
  ];

  final List<Outfit> outfits;

  @override
  Future<List<Outfit>> build() async => outfits;
}

/// No trips by default — most of this file's tests don't care about trip
/// data, and it isn't needed for a "fully set up" account (see
/// [_FakeGarmentsNotifier]'s own doc; closet + a created outfit already
/// cover the "established user" signal — see home_page.dart's
/// `_isEstablishedUser`).
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

      // The date/weather header stays visible even during Getting Started
      // — only the Today's Outfit/Upcoming Trip/Recently Added content
      // below it is replaced.
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(find.text('Welcome to Uwearis'), findsOneWidget);
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Full-Body Photo'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text("Today's Outfit"), findsNothing);
      expect(find.text('Recently Added'), findsNothing);
    },
  );

  testWidgets(
    'reference photos done but an empty closet shows the Build your closet '
    'step, not the photo checklist',
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

      expect(find.text('Build your closet'), findsOneWidget);
      expect(find.text('Add Clothing'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Profile Photo'), findsNothing);
    },
  );

  testWidgets(
    'a closet covering only two of the three required categories (Top + '
    'Bottom, no Shoes) still shows the Build your closet step, not the '
    'first-outfit step',
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

      expect(find.text('Build your closet'), findsOneWidget);
      expect(find.text('Ready for your first look?'), findsNothing);
    },
  );

  testWidgets(
    'photos and closet done but no outfit created yet shows the final '
    '"Ready for your first look?" Getting Started step, not normal Home',
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

      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Ready for your first look?'), findsOneWidget);
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
      expect(find.text('Getting Started'), findsNothing);
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
      expect(find.text('Getting Started'), findsNothing);
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

      // A planned trip alone isn't enough to skip straight past the photo
      // step (see home_page.dart's _isEstablishedUser — trip data only
      // matters once closet/outfit are also both done); still Getting
      // Started, from the top.
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Profile Photo'), findsOneWidget);
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

      expect(find.text('Getting Started'), findsNothing);
      expect(find.text("Today's Outfit"), findsOneWidget);
    },
  );

  testWidgets(
    'a fully set-up user with no outfit generated for today specifically '
    '(but has created outfits before) sees nothing in that slot — no '
    '"first look" CTA, since it is not their first outfit any more',
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
      expect(find.text('Ready for your first look?'), findsNothing);
      expect(find.text('No outfit image yet'), findsNothing);
      // The "Today's Outfit" divider is reserved for when the backend has
      // actually returned an outfit for today.
      expect(find.text("Today's Outfit"), findsNothing);
    },
  );

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
      expect(find.text('Build your closet'), findsOneWidget);

      // Simulates GarmentUploadHelper's onAdded callback (the same
      // optimistic update closet_page.dart / main_shell.dart use) after the
      // user completes the existing Add Clothing flow.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      container.read(garmentsProvider.notifier).addGarment(_shoesGarment);
      await tester.pump();

      // outfitsProvider's default fake already has a created outfit, so
      // adding the last missing piece (Shoes) completes Getting Started.
      expect(find.text('Build your closet'), findsNothing);
      expect(find.text('Getting Started'), findsNothing);
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
    },
  );

  testWidgets(
    'creating the first outfit while Home stays mounted (IndexedStack) '
    'flips Getting Started straight to normal Home on its own, via the '
    'shared outfitsProvider',
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
      expect(find.text('Ready for your first look?'), findsOneWidget);

      // Simulates OutfitDetailsPage's post-save outfitsProvider.refresh()
      // picking up the newly created outfit.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      container.read(outfitsProvider.notifier).addOutfit(
        Outfit(id: 200, imageUrl: 'https://example.com/new-outfit.jpg'),
      );
      await tester.pump();

      expect(find.text('Ready for your first look?'), findsNothing);
      expect(find.text('Getting Started'), findsNothing);
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
    },
  );

  testWidgets(
    'regression: ref.invalidate (as login does via '
    'invalidateSignedInProviders) must not flash the previous account\'s '
    'stale Home content while the new account\'s fetch is still in flight',
    (tester) async {
      // Account A: fully set up (normal Home, no Getting Started).
      final dailyOutfit = _FakeDailyOutfitNotifier([
        Outfit(id: 1, imageUrl: 'https://example.com/outfit.jpg'),
      ]);
      const delay = Duration(milliseconds: 50);
      await pumpApp(
        tester,
        HomePage(now: () => DateTime(2026, 9, 17, 10)),
        overrides: overridesWith(
          dailyOutfit,
          garments: _DelayedGarmentsNotifier(
            const [_topGarment, _bottomGarment, _shoesGarment],
            delay: delay,
          ),
        ),
      );
      await tester.pump();
      // Advances the fake clock past the initial fetch's delay — a plain
      // zero-duration pump() never fires a Future.delayed.
      await tester.pump(delay);
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
      expect(find.text('Getting Started'), findsNothing);

      // Login for account B calls invalidateSignedInProviders right before
      // swapping in a fresh MainShell — here, HomePage stays the same
      // widget (this test isn't re-simulating the MainShell swap), but
      // container.invalidate is the exact same call that function makes.
      // Riverpod's own AsyncLoading after an invalidate still carries
      // account A's already-resolved value via copyWithPrevious, which is
      // the whole point of this regression test.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      container.invalidate(garmentsProvider);
      await tester.pump();

      // Still mid-refetch (the delayed notifier hasn't resolved yet — the
      // clock hasn't been advanced past `delay` since the invalidate) —
      // must show neither account's content, not fall through to A's
      // still-attached stale value.
      expect(find.text('Thursday, Sep 17'), findsNothing);
      expect(find.text('Getting Started'), findsNothing);

      // The refetch resolves (same data here — this test is about the
      // loading window itself, not about B seeing different data).
      await tester.pump(delay);
      expect(find.text('Thursday, Sep 17'), findsOneWidget);
    },
  );
}
