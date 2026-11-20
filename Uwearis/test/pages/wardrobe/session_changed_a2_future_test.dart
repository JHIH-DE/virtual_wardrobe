import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
import 'package:uwearis/features/pages/wardrobe/create_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/garment_details_page.dart';
import 'package:uwearis/features/pages/wardrobe/outfits_page.dart';
import 'package:uwearis/features/pages/wardrobe/trip_details_page.dart';
import 'package:uwearis/features/pages/wardrobe/trips_page.dart';
import 'package:uwearis/features/pages/wardrobe/wardrobe_home_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/wardrobe_nav_bar.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

// Finding #1, batch A2 (provider futures): entry points that wait on a
// provider's load before opening a page. A load that ends after its session
// did fails with SessionChangedException; each entry point runs the same
// five scenarios as A1-a / A1-b.

class _FakeOutfits extends OutfitsNotifier {
  @override
  Future<List<Outfit>> build() async => const [];

  @override
  Future<void> refresh() async {}
}

class _FakeDailyOutfits extends DailyOutfitNotifier {
  @override
  Future<List<Outfit>> build() async => const [];

  @override
  Future<void> refresh() async {}
}

class _FakeWeather extends WeatherNotifier {
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

class _FakeProfile extends ProfileNotifier {
  @override
  Future<ProfileData> build() async => ProfileData(
    profile: UserProfile(
      name: 'Test User',
      gender: 'Prefer not to say',
      location: 'Test City',
      birthDate: DateTime(1995, 1, 1),
    ),
    bodyRefUrl: 'https://example.com/body.jpg',
    faceRefUrl: 'https://example.com/face.jpg',
  );
}

final _trip = Trip(
  id: '7',
  name: 'Kyoto Autumn',
  activities: const ['sightseeing'],
  legs: [
    TripLeg(
      location: LocationResult(
        name: 'Kyoto',
        latitude: 35,
        longitude: 135,
        timezone: 'Asia/Tokyo',
      ),
      dateRange: DateTimeRange(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 4),
      ),
    ),
  ],
);

Map<String, dynamic> _garmentJson(int id, String category) => {
  'id': id,
  'name': 'Garment $id',
  'category': category,
  'sub_category': '',
  'image_url': '',
  'is_favorite': false,
  'is_deleted': false,
};

/// A closet that completes Getting Started's closet step.
final _closetJson = {
  'items': [
    _garmentJson(1, 'Top'),
    _garmentJson(2, 'Bottom'),
    _garmentJson(3, 'Shoes'),
    _garmentJson(501, 'Shoes'),
  ],
  'total': 4,
};

final _tripCollection = {
  'trip_id': 7,
  'total_days': 4,
  'suggested_outfit_count': {'min': 4, 'max': 6},
  'suitcase_items': <Object>[],
  'outfits': <Object>[],
  'refresh_batch_size': 0,
  'ai_added_count': 0,
  'ai_status': 'no_new',
};

final _closetAnalysis = {
  'versatility': {'level': 8, 'label': 'Versatile'},
  'outfit_ideas': [
    {
      'title': 'Idea',
      'garments': [
        {
          'garment_id': 501,
          'category': 'Shoes',
          'name': 'Garment 501',
          'image_url': '',
          'is_target': true,
        },
      ],
    },
  ],
  'similar_garments': <Object?>[],
};

/// One entry point under test.
class _Entry {
  _Entry({
    required this.name,
    required this.open,
    required this.trigger,
    required this.isOwnRequest,
    required this.okReply,
    required this.failure,
    this.overrides = const [],
    this.holdFromStart = true,
  });

  final String name;
  final Future<void> Function(WidgetTester tester, BuildContext root) open;
  final Future<void> Function(WidgetTester tester) trigger;
  final bool Function(http.Request request) isOwnRequest;
  final http.Response Function() okReply;

  /// The error copy a same-session failure shows.
  final Finder failure;
  final List<Override> overrides;

  /// False: the first matching request is answered with [okReply] (the
  /// page needs it loaded), only later ones are held.
  final bool holdFromStart;
}

class _Backend {
  _Backend(this.entry) : _holding = entry.holdFromStart;
  final _Entry entry;
  bool _holding;
  final _held = <Completer<http.Response>>[];
  http.Response? _reply;
  final requests = <String>[];

  int get heldCount => _held.length;

  /// From now on the entry's own requests wait for [release].
  void hold() => _holding = true;

  /// Answers the held request, and any retry of it, with [res].
  void release(http.Response res) {
    _reply = res;
    for (final c in _held) {
      if (!c.isCompleted) c.complete(res);
    }
  }

  MockClient client() => MockClient((req) async {
    requests.add('${req.method} ${req.url.path}');
    if (entry.isOwnRequest(req)) {
      final reply = _reply;
      if (reply != null) return reply;
      if (!_holding) return entry.okReply();
      final c = Completer<http.Response>();
      _held.add(c);
      return c.future;
    }
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (req.method == 'GET' && path.endsWith('/garments')) {
      return jsonResponse(envelope(_closetJson));
    }
    if (req.method == 'POST' && path.endsWith('/closet-analysis')) {
      return jsonResponse(envelope(_closetAnalysis));
    }
    if (path.contains('/trip_plans/7/outfits')) {
      return jsonResponse(envelope(_tripCollection));
    }
    return jsonResponse(envelope({'items': <Object>[]}));
  });
}

late _Backend _backend;

/// The shell overlay's last reported state.
bool _shellLoading = false;

Widget _inShell(Widget child) => Builder(
  builder: (_) => WardrobeShellScope(
    selectTab: (_) {},
    setLoading: (loading, {label, required tab}) => _shellLoading = loading,
    child: child,
  ),
);

final _sessionExpired = find.text('Session Expired');
final _retry = find.text('Retry');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pushPage(
  WidgetTester tester,
  BuildContext root,
  Widget page,
) async {
  unawaited(Navigator.of(root).push(MaterialPageRoute(builder: (_) => page)));
  await _settle(tester);
}

late BuildContext _baseContext;
late WidgetRef _baseRef;

final _entries = <_Entry>[
  _Entry(
    name: 'openTripDetails',
    open: (tester, root) => _pushPage(
      tester,
      root,
      _inShell(
        Consumer(
          builder: (context, ref, _) {
            _baseContext = context;
            _baseRef = ref;
            return const Scaffold(body: Text('Base page'));
          },
        ),
      ),
    ),
    trigger: (tester) async {
      unawaited(
        openTripDetails(
          _baseContext,
          _baseRef,
          _trip,
          tab: WardrobeTab.tripPlanner,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(_shellLoading, isTrue, reason: 'loading shown');
    },
    isOwnRequest: (r) =>
        r.method == 'POST' && r.url.path.endsWith('/trip_plans/7/outfits/sync'),
    okReply: () => jsonResponse(envelope(_tripCollection)),
    failure: find.text('Failed to load trip details'),
  ),
  _Entry(
    name: 'OutfitsPage._openAddOutfit',
    overrides: [outfitsProvider.overrideWith(_FakeOutfits.new)],
    open: (tester, root) =>
        _pushPage(tester, root, _inShell(const OutfitsPage())),
    trigger: (tester) async {
      await tester.tap(find.text('Create Outfit'));
      await tester.pump();
      expect(_shellLoading, isTrue, reason: 'loading shown');
    },
    isOwnRequest: (r) => r.method == 'GET' && r.url.path.endsWith('/garments'),
    okReply: () => jsonResponse(envelope(_closetJson)),
    failure: find.text('Failed to load garments'),
  ),
  _Entry(
    name: 'WardrobeHomePage._openAddOutfit',
    holdFromStart: false,
    overrides: [
      dailyOutfitProvider.overrideWith(_FakeDailyOutfits.new),
      outfitsProvider.overrideWith(_FakeOutfits.new),
      tripsProvider.overrideWith(() => SeededTripsNotifier(const [])),
      weatherProvider.overrideWith(_FakeWeather.new),
      profileProvider.overrideWith(_FakeProfile.new),
    ],
    open: (tester, root) => _pushPage(
      tester,
      root,
      _inShell(WardrobeHomePage(now: () => DateTime(2026, 9, 17, 10))),
    ),
    trigger: (tester) async {
      // Getting Started's next step is Create Outfit once the closet is
      // ready; the closet is re-read while it's tapped.
      expect(find.text('Next'), findsOneWidget);
      _backend.hold();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WardrobeHomePage)),
      );
      unawaited(container.read(garmentsProvider.notifier).refresh());
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump();
    },
    isOwnRequest: (r) => r.method == 'GET' && r.url.path.endsWith('/garments'),
    okReply: () => jsonResponse(envelope(_closetJson)),
    failure: find.text('Failed to load garments'),
  ),
  _Entry(
    name: 'GarmentDetailsPage._openAddOutfitFromIdea',
    open: (tester, root) => _pushPage(
      tester,
      root,
      const GarmentDetailsPage(
        initialGarment: Garment(
          id: 501,
          name: 'Boots',
          category: GarmentCategory.shoes,
          subCategory: 'Boots',
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
        ),
      ),
    ),
    trigger: (tester) async {
      await tester.tap(find.text('View Match'));
      await _settle(tester);
      await tester.tap(find.text('Try It On'));
      await tester.pump();
    },
    isOwnRequest: (r) => r.method == 'GET' && r.url.path.endsWith('/garments'),
    okReply: () => jsonResponse(envelope(_closetJson)),
    failure: find.text('Failed to load garments'),
  ),
];

void main() {
  setUp(() {
    _shellLoading = false;
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Taps every dialog's dismiss button, top first, until none is left, so
  /// a failed assertion can't leave AuthExpiredHandler's guard held.
  Future<void> closeDialogs(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      final buttons = find.byKey(AppDialog.dismissButtonKey);
      if (buttons.evaluate().isEmpty) break;
      await tester.tap(buttons.last);
      await _settle(tester);
    }
    while (tester.takeException() != null) {}
  }

  /// Pages a session-ended load must not have opened.
  int openedPages() =>
      find.byType(CreateOutfitPage).evaluate().length +
      find.byType(TripDetailsPage).evaluate().length;

  for (final e in _entries) {
    group(e.name, () {
      late BuildContext root;

      Future<void> start(WidgetTester tester) async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          Builder(
            builder: (context) {
              root = context;
              return const Scaffold(body: Text('Root'));
            },
          ),
          overrides: e.overrides,
          retry: (_, _) => null,
        );
        // Kept listened, as the shell's tabs keep it (it also lets
        // appRetryPolicy's retries run).
        final sub = ProviderScope.containerOf(
          root,
        ).listen(garmentsProvider, (_, _) {});
        addTearDown(sub.close);
        await tester.pump();
        await e.open(tester, root);
        await e.trigger(tester);
        expect(
          _backend.heldCount,
          1,
          reason: 'its load is in flight: ${_backend.requests}',
        );
        expect(openedPages(), 0);
      }

      Future<void> run(
        WidgetTester tester,
        Future<void> Function() body,
      ) async {
        _backend = _Backend(e);
        await http.runWithClient(body, _backend.client);
      }

      Future<void> signOutTo(Widget page) async {
        final navigator = Navigator.of(root);
        await clearSignedInSession();
        unawaited(
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => page),
            (_) => false,
          ),
        );
      }

      testWidgets('session expired meanwhile: no error over Session Expired, '
          'nothing opened, loading cleared', (tester) async {
        await run(tester, () async {
          await start(tester);
          unawaited(AuthExpiredHandler.handle(root));
          await tester.pump();
          await tester.pump();
          expect(_sessionExpired, findsOneWidget);

          _backend.release(e.okReply());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final shown = {
            'error': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'sessionExpired': _sessionExpired.evaluate().length,
            'opened': openedPages(),
            'loading': _shellLoading,
          };
          await closeDialogs(tester);
          expect(shown, {
            'error': 0,
            'retry': 0,
            'sessionExpired': 1,
            'opened': 0,
            'loading': false,
          });
        });
      });

      testWidgets('sign-out meanwhile: no error over the login page', (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          await signOutTo(const LoginPage());
          await tester.pump();
          _backend.release(e.okReply());
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          while (tester.takeException() != null) {}

          final shown = {
            'error': e.failure.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
            'opened': openedPages(),
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'login': 1, 'opened': 0});
        });
      });

      testWidgets('a load ending after the page is gone touches nothing', (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          await signOutTo(const Scaffold(body: Text('Signed out')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));

          _backend.release(e.okReply());
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);
          expect(find.text('Signed out'), findsOneWidget);
          expect(find.byType(AppDialog), findsNothing);
          expect(openedPages(), 0);
        });
      });

      testWidgets("the same session's 500 still shows its error", (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          _backend.release(jsonResponse(envelope(null), status: 500));
          // appRetryPolicy retries a 5xx (~2.9s in all).
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(seconds: 1));
          }

          final shown = {
            'error': e.failure.evaluate().length,
            'loading': _shellLoading,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 1, 'loading': false});
        });
      });

      testWidgets("the same session's own expiry still goes to Session "
          'Expired', (tester) async {
        await run(tester, () async {
          await start(tester);
          _backend.release(http.Response('{}', 401));
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final shown = {
            'error': e.failure.evaluate().length,
            'sessionExpired': _sessionExpired.evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'sessionExpired': 1});
        });
      });
    });
  }
}
