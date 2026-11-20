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
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/settings/settings_page.dart';
import 'package:uwearis/features/pages/wardrobe/today_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/trip_details_page.dart';
import 'package:uwearis/features/pages/wardrobe/trip_suitcase_page.dart';
import 'package:uwearis/features/pages/wardrobe/trips_page.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/outfit/outfit_card.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

// Finding #1, batch A1-b: Home / Today / Trips / Settings actions whose
// reply lands after their session ended get SessionChangedException. Each
// entry point runs the same five scenarios as A1-a. (Home's heart is
// covered in wardrobe_home_page_test.dart, which has its harness.)

class _FakeDailyOutfits extends DailyOutfitNotifier {
  _FakeDailyOutfits(this._seed);
  final List<Outfit> _seed;

  @override
  Future<List<Outfit>> build() async => _seed;

  @override
  Future<void> refresh() async {}
}

class _FakeOutfits extends OutfitsNotifier {
  _FakeOutfits(this._seed);
  final List<Outfit> _seed;

  @override
  Future<List<Outfit>> build() async => _seed;

  @override
  Future<void> refresh() async {}
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

const _tee = {'garment_id': 1, 'name': 'Tee', 'category': 'top'};
const _jeans = {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'};

Map<String, dynamic> _collection(List<Map<String, dynamic>> suitcase) => {
  'trip_id': 7,
  'total_days': 4,
  'suggested_outfit_count': {'min': 4, 'max': 6},
  'suitcase_items': suitcase,
  'outfits': <Object>[],
  'refresh_batch_size': 0,
  'ai_added_count': 0,
  'ai_status': 'no_new',
};

Garment _closetGarment(int id, String name, GarmentCategory category) =>
    Garment(
      id: id,
      garmentId: id,
      name: name,
      category: category,
      subCategory: '',
      uploadUrl: '',
      objectName: '',
    );

final _closet = [
  _closetGarment(1, 'Tee', GarmentCategory.top),
  _closetGarment(2, 'Jeans', GarmentCategory.bottom),
  _closetGarment(3, 'Sneakers', GarmentCategory.shoes),
];

final _todayOutfit = Outfit(
  id: 10,
  groupId: 1,
  name: 'Office',
  imageUrl: '',
  garmentIds: const [],
);

/// One entry point under test.
class _Entry {
  _Entry({
    required this.name,
    required this.open,
    required this.trigger,
    required this.isOwnRequest,
    required this.okReply,
    required this.failure,
    required this.rolledBack,
    this.overrides = const [],
    this.suitcase = const [_tee],
  });

  final String name;

  /// Opens the page from Root's context; returns the context the entry
  /// point runs with.
  final Future<void> Function(WidgetTester tester, BuildContext root) open;

  /// Starts the action; its request is held until the scenario releases it.
  final Future<void> Function(WidgetTester tester) trigger;
  final bool Function(http.Request request) isOwnRequest;
  final http.Response Function() okReply;

  /// The error copy a same-session failure shows.
  final Finder failure;

  /// After the session ended: the optimistic change is undone, in-flight
  /// state reset, nothing navigated or written to a provider.
  final void Function(WidgetTester tester, ProviderContainer container)
  rolledBack;

  final List<Override> overrides;

  /// What trip 7's collection reads answer.
  final List<Map<String, dynamic>> suitcase;
}

class _Backend {
  _Backend(this.entry);
  final _Entry entry;
  final _held = <Completer<http.Response>>[];
  final requests = <String>[];

  int get heldCount => _held.length;

  void release(http.Response res) {
    for (final c in _held) {
      if (!c.isCompleted) c.complete(res);
    }
  }

  MockClient client() => MockClient((req) async {
    requests.add('${req.method} ${req.url.path}');
    if (entry.isOwnRequest(req)) {
      final c = Completer<http.Response>();
      _held.add(c);
      return c.future;
    }
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if ((req.method == 'GET' && path.endsWith('/trip_plans/7/outfits')) ||
        (req.method == 'POST' && path.endsWith('/trip_plans/7/outfits/sync'))) {
      return jsonResponse(envelope(_collection(entry.suitcase)));
    }
    if (path.endsWith('/packing-analysis')) {
      return jsonResponse(envelope({'overall_advice': null, 'categories': []}));
    }
    return jsonResponse(envelope({'items': <Object>[]}));
  });
}

final _sessionExpired = find.text('Session Expired');
final _retry = find.text('Retry');

/// Fixed pumps: several of these pages keep an animation running.
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

/// A page whose context and ref run a top-level Trips helper.
Future<void> _pushBase(WidgetTester tester, BuildContext root) => _pushPage(
  tester,
  root,
  Consumer(
    builder: (context, ref, _) {
      ref.watch(tripsProvider);
      _baseContext = context;
      _baseRef = ref;
      return const Scaffold(body: Text('Base page'));
    },
  ),
);

List<Trip> _tripsIn(ProviderContainer c) =>
    c.read(tripsProvider).value ?? const [];

final _entries = <_Entry>[
  _Entry(
    name: 'TodayOutfitPage._saveTags',
    overrides: [
      dailyOutfitProvider.overrideWith(() => _FakeDailyOutfits([_todayOutfit])),
      outfitsProvider.overrideWith(() => _FakeOutfits(const [])),
    ],
    open: (tester, root) => _pushPage(tester, root, const TodayOutfitPage()),
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.sell_outlined));
      await _settle(tester);
      await tester.tap(find.text('Winter'));
      await _settle(tester);
      await tester.tapAt(const Offset(10, 10)); // closing the sheet saves
      await _settle(tester);
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/outfit/1/10'),
    okReply: () => jsonResponse(envelope({'outfit_id': 10, 'group_id': 1})),
    failure: find.text("Couldn't update this outfit. Please try again."),
    rolledBack: (tester, c) {
      expect(find.text('Winter'), findsNothing, reason: 'tags');
      expect(c.read(dailyOutfitProvider).value!.single.seasons, isEmpty);
      final button = tester.widget<CircleIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.sell_outlined),
          matching: find.byType(CircleIconButton),
        ),
      );
      expect(button.onPressed, isNotNull, reason: 'tag button usable');
    },
  ),
  _Entry(
    name: 'TodayOutfitPage._toggleFavorite',
    overrides: [
      dailyOutfitProvider.overrideWith(() => _FakeDailyOutfits([_todayOutfit])),
      outfitsProvider.overrideWith(() => _FakeOutfits(const [])),
    ],
    open: (tester, root) => _pushPage(tester, root, const TodayOutfitPage()),
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget, reason: 'optimistic');
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/outfit/1/10'),
    okReply: () => jsonResponse(envelope({'outfit_id': 10, 'group_id': 1})),
    failure: find.text('Failed to update favorite'),
    rolledBack: (tester, c) {
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(c.read(dailyOutfitProvider).value!.single.isFavorite, isFalse);
    },
  ),
  _Entry(
    name: 'handleRenameTrip',
    overrides: [
      tripsProvider.overrideWith(() => SeededTripsNotifier([_trip])),
    ],
    open: _pushBase,
    trigger: (tester) async {
      unawaited(handleRenameTrip(_baseContext, _baseRef, _trip, 'Renamed'));
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/trip_plans/7'),
    okReply: () => jsonResponse(envelope({'id': 7})),
    failure: find.text('Failed to update trip'),
    rolledBack: (tester, c) {
      expect(_tripsIn(c).single.name, 'Kyoto Autumn', reason: 'rename');
    },
  ),
  _Entry(
    name: 'handleDeleteTrip',
    overrides: [
      tripsProvider.overrideWith(() => SeededTripsNotifier([_trip])),
    ],
    open: _pushBase,
    trigger: (tester) async {
      unawaited(handleDeleteTrip(_baseContext, _baseRef, _trip));
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'DELETE' && r.url.path.endsWith('/trip_plans/7'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text('Failed to delete trip'),
    rolledBack: (tester, c) {
      expect(_tripsIn(c).map((t) => t.id), ['7'], reason: 'trip kept');
      expect(find.text('Base page', skipOffstage: false), findsOneWidget);
    },
  ),
  _Entry(
    name: 'TripDetailsPage._updateTrip',
    overrides: [
      tripsProvider.overrideWith(() => SeededTripsNotifier([_trip])),
    ],
    open: (tester, root) async {
      await _pushPage(tester, root, TripDetailsPage(trip: _trip));
      expect(find.text('Kyoto Autumn'), findsWidgets);
    },
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await _settle(tester);
      await tester.tap(find.text('Edit Name'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Renamed');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await _settle(tester);
      expect(find.text('Renamed'), findsWidgets, reason: 'optimistic');
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/trip_plans/7'),
    okReply: () => jsonResponse(envelope({'id': 7})),
    failure: find.text('Failed to update trip'),
    rolledBack: (tester, c) {
      expect(find.text('Renamed'), findsNothing, reason: 'page title');
      expect(_tripsIn(c).single.name, 'Kyoto Autumn', reason: 'provider');
    },
  ),
  _Entry(
    name: 'TripSuitcasePage._removeGarment',
    suitcase: const [_tee, _jeans],
    open: (tester, root) =>
        _pushPage(tester, root, TripSuitcasePage(trip: _trip)),
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.close).first);
      await _settle(tester);
      await tester.tap(find.text('REMOVE'));
      await _settle(tester);
      expect(find.text('Tee'), findsNothing, reason: 'optimistic');
    },
    isOwnRequest: (r) =>
        r.method == 'DELETE' && r.url.path.endsWith('/suitcase-items/1'),
    okReply: () => jsonResponse(envelope({'affected_options': <Object>[]})),
    failure: find.text('Failed to remove item'),
    rolledBack: (tester, _) {
      expect(find.text('Tee'), findsOneWidget, reason: 'put back');
    },
  ),
  _Entry(
    name: 'TripSuitcasePage._commitChanges',
    overrides: [
      garmentsProvider.overrideWith(
        () => SeededGarmentsNotifier(_closet, refreshReseeds: true),
      ),
    ],
    open: (tester, root) =>
        _pushPage(tester, root, TripSuitcasePage(trip: _trip)),
    trigger: (tester) async {
      // Stage Jeans through the picker, then leave: leaving commits.
      await tester.tap(find.byType(ActionDiscButton).last);
      await _settle(tester);
      await tester.tap(find.text('Bottom'));
      await _settle(tester);
      await tester.tap(find.text('Jeans'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Jeans'), findsOneWidget, reason: 'staged');
      await tester.binding.handlePopRoute();
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'POST' && r.url.path.endsWith('/suitcase-items'),
    okReply: () => jsonResponse(
      envelope({
        'suitcase_items': [_tee, _jeans],
      }),
    ),
    failure: find.text('Failed to update suitcase'),
    rolledBack: (tester, _) {
      // false: leaving stopped, the staged garment kept.
      expect(find.byType(TripSuitcasePage), findsOneWidget, reason: 'stayed');
      expect(find.text('Jeans'), findsOneWidget, reason: 'still staged');
    },
  ),
  _Entry(
    name: 'TripSuitcasePage._addFromOutfit',
    overrides: [
      outfitsProvider.overrideWith(
        () => _FakeOutfits([
          Outfit(id: 50, imageUrl: '', garmentIds: const [1, 3]),
        ]),
      ),
      garmentsProvider.overrideWith(
        () => SeededGarmentsNotifier(_closet, refreshReseeds: true),
      ),
    ],
    open: (tester, root) =>
        _pushPage(tester, root, TripSuitcasePage(trip: _trip)),
    trigger: (tester) async {
      await tester.tap(find.text('Add from a Saved Outfit'));
      await _settle(tester);
      await tester.tap(find.byType(OutfitCard));
      await _settle(tester);
      await tester.tap(find.text('Add to Trip'));
      await _settle(tester);
    },
    isOwnRequest: (r) =>
        r.method == 'POST' && r.url.path.endsWith('/outfits/from-saved'),
    okReply: () => jsonResponse(envelope(_collection(const [_tee]))),
    failure: find.text("Couldn't add this outfit. Please try again."),
    rolledBack: (tester, _) {
      expect(find.byType(TripSuitcasePage), findsOneWidget);
      expect(find.text('Sneakers'), findsNothing, reason: 'nothing packed');
      expect(find.textContaining('Added to this trip'), findsNothing);
      expect(
        find.text('Add from a Saved Outfit'),
        findsOneWidget,
        reason: 'usable again',
      );
    },
  ),
  _Entry(
    name: 'SettingsPage._deleteAccount',
    open: (tester, root) => _pushPage(tester, root, const SettingsPage()),
    trigger: (tester) async {
      await tester.tap(find.text('Delete My Account'));
      await _settle(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Delete My Account'),
      );
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'DELETE' && r.url.path.endsWith('/users/me'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text("Couldn't delete your account — please try again."),
    rolledBack: (tester, _) {
      expect(find.byType(SettingsPage), findsOneWidget, reason: 'stayed');
      expect(
        find.widgetWithText(ElevatedButton, 'Delete My Account'),
        findsNothing,
        reason: 'confirm closed',
      );
    },
  ),
];

void main() {
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
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

  for (final e in _entries) {
    group(e.name, () {
      late BuildContext root;
      late ProviderContainer container;
      late _Backend backend;

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
        container = ProviderScope.containerOf(root);
        // Kept loaded, as the shell's tabs keep them.
        for (final p in [tripsProvider, dailyOutfitProvider, outfitsProvider]) {
          final sub = container.listen(p, (_, _) {});
          addTearDown(sub.close);
        }
        await tester.pump();
        await e.open(tester, root);
        await e.trigger(tester);
        expect(
          backend.heldCount,
          1,
          reason: 'its request is in flight: ${backend.requests}',
        );
      }

      Future<void> run(
        WidgetTester tester,
        Future<void> Function() body,
      ) async {
        backend = _Backend(e);
        await http.runWithClient(body, backend.client);
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

      testWidgets('session expired meanwhile: no error or Retry over Session '
          'Expired, and the change is rolled back', (tester) async {
        await run(tester, () async {
          await start(tester);
          unawaited(AuthExpiredHandler.handle(root));
          await tester.pump();
          await tester.pump();
          expect(_sessionExpired, findsOneWidget);

          backend.release(e.okReply());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final shown = {
            'error': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'sessionExpired': _sessionExpired.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
          };
          try {
            // Behind Session Expired, still on the page.
            e.rolledBack(tester, container);
          } finally {
            await closeDialogs(tester);
          }
          expect(shown, {
            'error': 0,
            'retry': 0,
            'sessionExpired': 1,
            'login': 0,
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
          backend.release(e.okReply());
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          while (tester.takeException() != null) {}

          final shown = {
            'error': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'retry': 0, 'login': 1});
        });
      });

      testWidgets('a reply after the page is gone touches nothing', (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          await signOutTo(const Scaffold(body: Text('Signed out')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));

          backend.release(e.okReply());
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);
          expect(find.text('Signed out'), findsOneWidget);
          expect(e.failure, findsNothing);
          expect(find.byType(AppDialog), findsNothing);
        });
      });

      testWidgets("the same session's 500 still shows its error", (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          backend.release(jsonResponse(envelope(null), status: 500));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final shown = e.failure.evaluate().length;
          await closeDialogs(tester);
          expect(shown, 1);
        });
      });

      testWidgets("the same session's own expiry still goes to Session "
          'Expired', (tester) async {
        await run(tester, () async {
          await start(tester);
          backend.release(http.Response('{}', 401));
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
