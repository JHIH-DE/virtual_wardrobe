import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/adjustment_options_provider.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/providers/sub_category_provider.dart';
import 'package:uwearis/core/providers/trip_detail_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/garment_sub_category.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/settings/reference_photos_page.dart';
import 'package:uwearis/features/pages/wardrobe/create_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/garment_details_page.dart';
import 'package:uwearis/features/pages/wardrobe/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/cards/swipe_action_card.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';

// C3: a single AI call whose session ends before its reply lands. The
// reply is a SessionChangedException (withAuth); whatever ended the session
// owns the UI, so the page shows no failure / Retry, applies nothing, starts
// nothing more, and clears its loading. Same-session 500 / 401 / success
// are unchanged.

class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._seed);
  final List<Garment> _seed;

  @override
  Future<List<Garment>> build() async => _seed;

  @override
  Future<void> refresh() async => state = AsyncData(_seed);
}

class _FakeOutfits extends OutfitsNotifier {
  @override
  Future<List<Outfit>> build() async => const [];

  @override
  Future<void> refresh() async => state = const AsyncData([]);
}

class _FakeWeather extends WeatherNotifier {
  @override
  Future<WeatherData> build() async => WeatherData(
    location: 'Test City',
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

class _FakeProfile extends ProfileNotifier {
  @override
  Future<ProfileData> build() async => const ProfileData(
    profile: UserProfile(name: 'Account A'),
    bodyRefUrl: 'https://example.com/body.jpg',
    faceRefUrl: 'https://example.com/face.jpg',
  );
}

Garment _garment(int id, String name, GarmentCategory category) => Garment(
  id: id,
  garmentId: id,
  name: name,
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
);

final _closet = [
  _garment(1, 'Tee', GarmentCategory.top),
  _garment(2, 'Jeans', GarmentCategory.bottom),
  _garment(3, 'Sneakers', GarmentCategory.shoes),
];

List<Override> _createOutfitOverrides() => [
  garmentsProvider.overrideWith(() => _FakeGarments(_closet)),
  adjustmentOptionsProvider.overrideWith((ref, _) async => const {}),
  subCategoryCatalogProvider.overrideWith(
    (ref, _) async => SubCategoryCatalog(const {}),
  ),
  weatherProvider.overrideWith(_FakeWeather.new),
];

const _garmentId = 7701;
const _photoUrl = 'https://example.com/garment.png';
const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Map<String, dynamic> _garmentJson() => {
  'id': _garmentId,
  'garment_id': _garmentId,
  'name': 'Plain Tee',
  'category': 'Top',
  'sub_category': 'Tee',
  'image_url': _photoUrl,
};

const _editedGarment = Garment(
  id: _garmentId,
  name: 'Plain Tee',
  category: GarmentCategory.top,
  subCategory: 'Tee',
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
);

http.Response _closetAnalysis(int level) => jsonResponse(
  envelope({
    'versatility': {'level': level, 'label': 'Label $level'},
    'outfit_ideas': <Object?>[],
    'similar_garments': <Object?>[],
  }),
);

const _tee = {'garment_id': 1, 'name': 'Tee', 'category': 'top'};
const _jeans = {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'};
const _sneakers = {'garment_id': 3, 'name': 'Sneakers', 'category': 'shoes'};

Map<String, dynamic> _tripCollection({List<Object?> outfits = const []}) => {
  'trip_id': 7,
  'total_days': 4,
  'suggested_outfit_count': {'min': 4, 'max': 6},
  'suitcase_items': [_tee, _jeans, _sneakers],
  'outfits': outfits,
  'refresh_batch_size': 0,
  'ai_added_count': outfits.length,
  'ai_status': outfits.isEmpty ? 'no_new' : 'ok',
};

Trip _trip() => Trip(
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

final _matchResult = jsonResponse(
  envelope({
    'reference_id': 1,
    'roles': [
      {'role': 'top', 'match_status': 'strong_match', 'selected_garment_id': 1},
    ],
    'garments': [
      {
        'id': 1,
        'garment_id': 1,
        'name': 'Tee',
        'category': 'Top',
        'sub_category': '',
      },
    ],
  }),
);

/// Real file reads (the Match a Look photo) only advance outside fake
/// async; each step's callback then needs a pump.
Future<void> _driveIo(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

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

Future<String> _writePhoto(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('c3_match_look');
    addTearDown(() => dir.deleteSync(recursive: true));
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFF888888),
    );
    final image = await recorder.endRecording().toImage(4, 4);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${dir.path}/look.png');
    await file.writeAsBytes(png!.buffer.asUint8List());
    return file.path;
  }))!;
}

/// One AI entry point. Its own (charged) request is held until a test
/// answers it; the first [answerFirst] such requests are answered with
/// [okReply] at once (a result that must already be on screen).
class _Entry {
  _Entry({
    required this.name,
    required this.open,
    required this.trigger,
    required this.isOwnRequest,
    required this.okReply,
    required this.failure,
    required this.unchanged,
    required this.succeeded,
    this.answerFirst = 0,
    this.firstReply,
    this.hasRetry = false,
    this.otherReply,
    this.overrides = const [],
    this.usesIo = false,
  });

  final String name;
  final Future<void> Function(WidgetTester tester, BuildContext root) open;
  final Future<void> Function(WidgetTester tester) trigger;
  final bool Function(http.Request request) isOwnRequest;
  final http.Response Function() okReply;
  final int answerFirst;
  final http.Response Function()? firstReply;

  /// The error copy a same-session failure shows.
  final Finder failure;
  final bool hasRetry;

  /// After its session ended: nothing applied, nothing further sent,
  /// loading cleared.
  final Future<void> Function(WidgetTester tester, _Backend backend) unchanged;
  final Future<void> Function(WidgetTester tester, _Backend backend) succeeded;
  final http.Response? Function(http.Request request)? otherReply;
  final List<Override> overrides;
  final bool usesIo;
}

class _Backend {
  _Backend(this.entry);
  final _Entry entry;
  final _held = <Completer<http.Response>>[];
  final sent = <String>[];
  int _ownSeen = 0;

  int get heldCount => _held.length;

  /// How often the entry's own request was sent: a Retry would send it
  /// again.
  int get ownSends => _ownSeen - entry.answerFirst;

  int count(String needle) => sent.where((s) => s.endsWith(needle)).length;

  void release(http.Response res) {
    for (final c in _held) {
      if (!c.isCompleted) c.complete(res);
    }
  }

  MockClient client() => MockClient((req) async {
    sent.add('${req.method} ${req.url.path}');
    if (entry.isOwnRequest(req)) {
      _ownSeen++;
      if (_ownSeen <= entry.answerFirst) {
        return (entry.firstReply ?? entry.okReply)();
      }
      final c = Completer<http.Response>();
      _held.add(c);
      return c.future;
    }
    if (req.url.path.endsWith('/auth/refresh')) {
      return http.Response('{}', 401);
    }
    return entry.otherReply?.call(req) ??
        jsonResponse(envelope({'items': <Object>[]}));
  });
}

final _sessionExpired = find.text('Session Expired');
final _retry = find.text('Retry');
final _overlay = find.byType(LoadingOverlay);

final _entries = <_Entry>[
  // --- Create Outfit: Match a Look (two charged calls) ---
  for (final heldStage in ['reference', 'match'])
    _Entry(
      name: 'CreateOutfitPage._runMatchALook (held at /$heldStage)',
      usesIo: true,
      overrides: _createOutfitOverrides(),
      open: (tester, root) async {
        final photo = await _writePhoto(tester);
        await _pushPage(
          tester,
          root,
          CreateOutfitPage(initialMatchALookImagePath: photo),
        );
      },
      trigger: _driveIo,
      isOwnRequest: (r) =>
          r.method == 'POST' && r.url.path.endsWith('/match_look/$heldStage'),
      okReply: () => heldStage == 'reference'
          ? jsonResponse(envelope(<String, dynamic>{}))
          : _matchResult,
      failure: find.text("Couldn't match that photo. Please try again."),
      otherReply: (r) {
        final path = r.url.path;
        if (path.endsWith('/reference/init-upload')) {
          return jsonResponse(
            envelope({
              'upload_url': 'https://storage.example/look.jpg',
              'object_name': 'look.jpg',
            }),
          );
        }
        if (path.endsWith('/look.jpg')) return http.Response('', 200);
        if (path.endsWith('/match_look/reference')) {
          return jsonResponse(envelope(<String, dynamic>{}));
        }
        if (path.endsWith('/match_look/match')) return _matchResult;
        return null;
      },
      unchanged: (tester, b) async {
        expect(
          b.count('/match_look/match'),
          heldStage == 'match' ? 1 : 0,
          reason: 'no second paid call after the session ended',
        );
        expect(b.count('/match_look/reference'), 1, reason: 'no resend');
        expect(find.text('Matching Your Look…'), findsNothing);
        expect(find.text('1 pieces matched'), findsNothing);
      },
      succeeded: (tester, b) async {
        expect(find.text('1 pieces matched'), findsOneWidget);
        expect(find.text('Matching Your Look…'), findsNothing);
      },
    ),

  // --- Create Outfit: Finish with AI ---
  _Entry(
    name: 'CreateOutfitPage._completeWithAi',
    overrides: _createOutfitOverrides(),
    open: (tester, root) => _pushPage(tester, root, const CreateOutfitPage()),
    trigger: (tester) async {
      await tester.tap(find.widgetWithText(AccentPillButton, 'Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    },
    isOwnRequest: (r) => r.url.path.endsWith('/outfit/advice'),
    okReply: () => jsonResponse(
      envelope({
        'selected_garment_ids': [1, 2, 3],
        'items': <Object?>[],
      }),
    ),
    failure: find.text(
      "Couldn't complete your outfit with AI — please try again.",
    ),
    unchanged: (tester, b) async {
      expect(find.byType(SwipeActionCard), findsNothing);
      expect(find.text('Completing Your Outfit…'), findsNothing);
      expect(b.ownSends, 1);
    },
    succeeded: (tester, b) async {
      expect(find.byType(SwipeActionCard), findsNWidgets(3));
      expect(_overlay, findsNothing);
    },
  ),

  // --- Garment Details: Re-analyze ---
  _Entry(
    name: 'GarmentDetailsPage._runReanalysis',
    hasRetry: true,
    open: (tester, root) => _pushPage(
      tester,
      root,
      const GarmentDetailsPage(initialGarment: _editedGarment),
    ),
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Re-analyze'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Re-analyze'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
    isOwnRequest: (r) => r.url.path.endsWith('/garments/analyze-instant'),
    okReply: () => jsonResponse(
      envelope({
        'metadata': {'category': 'Top', 'sub_category': 'Hoodie'},
      }),
    ),
    otherReply: (r) {
      if (r.url.toString() == _photoUrl) return http.Response.bytes(_png, 200);
      if (r.method == 'PATCH' || r.url.path.endsWith('/garments/$_garmentId')) {
        return jsonResponse(envelope(_garmentJson()));
      }
      return null;
    },
    failure: find.text("Couldn't analyze this photo"),
    unchanged: (tester, b) async {
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Hoodie'), findsNothing);
      expect(find.text('Details Updated'), findsNothing);
      expect(
        b.sent.where((s) => s.startsWith('PATCH /api/v1/garments/')),
        isEmpty,
      );
      expect(b.ownSends, 1, reason: 'no retry');
    },
    succeeded: (tester, b) async {
      expect(find.text('Hoodie'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(
        b.sent.where((s) => s.startsWith('PATCH /api/v1/garments/')),
        isNotEmpty,
        reason: 'the result auto-saves: ${b.sent}',
      );
      expect(_overlay, findsNothing);
    },
  ),

  // --- Garment Details: Closet Match, first run ---
  _Entry(
    name: 'GarmentDetailsPage._runClosetAnalysis',
    open: (tester, root) => _pushPage(
      tester,
      root,
      const GarmentDetailsPage(initialGarment: _editedGarment),
    ),
    trigger: (tester) async {
      await tester.tap(find.text('View Match'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
    isOwnRequest: (r) =>
        r.method == 'POST' && r.url.path.endsWith('/closet-analysis'),
    okReply: () => _closetAnalysis(8),
    failure: find.text("Couldn't analyze — please try again."),
    unchanged: (tester, b) async {
      expect(find.text('8/10'), findsNothing);
      expect(find.text('Finding Matches…'), findsNothing);
      expect(await GarmentService().cachedClosetAnalysis(_garmentId), isNull);
      expect(b.ownSends, 1);
    },
    succeeded: (tester, b) async {
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('Finding Matches…'), findsNothing);
    },
  ),

  // --- Garment Details: Closet Match, refresh over a shown result ---
  _Entry(
    name: 'GarmentDetailsPage._refreshClosetAnalysis',
    answerFirst: 1,
    firstReply: () => _closetAnalysis(8),
    open: (tester, root) async {
      await _pushPage(
        tester,
        root,
        const GarmentDetailsPage(initialGarment: _editedGarment),
      );
      await tester.tap(find.text('View Match'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('8/10'), findsOneWidget);
    },
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'POST' && r.url.path.endsWith('/closet-analysis'),
    okReply: () => _closetAnalysis(3),
    failure: find.text("Couldn't analyze — please try again."),
    unchanged: (tester, b) async {
      expect(find.text('8/10'), findsOneWidget, reason: 'old result kept');
      expect(find.text('3/10'), findsNothing);
      expect(find.text('Finding Matches…'), findsNothing);
      // Sign-out clears the cache; the late result must not refill it.
      final cached = await GarmentService().cachedClosetAnalysis(_garmentId);
      expect(cached?.versatility.level, isNot(3));
      expect(b.ownSends, 1);
    },
    succeeded: (tester, b) async {
      expect(find.text('Finding Matches…'), findsNothing);
      expect(find.text('3/10'), findsOneWidget);
    },
  ),

  // --- Reference photos: Generate Virtual Model ---
  _Entry(
    name: 'BaseModelGenerationMixin.generateBaseModel',
    overrides: [profileProvider.overrideWith(_FakeProfile.new)],
    open: (tester, root) =>
        _pushPage(tester, root, const ReferencePhotosPage()),
    trigger: (tester) async {
      await tester.tap(find.text('Generate Virtual Model'));
      await tester.pump();
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'POST' && r.url.path.endsWith('/base-model/generate'),
    // '' not a real URL: a real fetch needs a sqflite factory.
    okReply: () => jsonResponse(envelope({'object_url': ''})),
    failure: find.text(
      "Couldn't generate your virtual model. Please try again.",
    ),
    unchanged: (tester, b) async {
      expect(find.byType(ReferencePhotosPage), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReferencePhotosPage)),
      );
      expect(container.read(profileProvider).value!.baseModelUrl, isNull);
      expect(b.ownSends, 1);
    },
    succeeded: (tester, b) async {
      expect(find.byType(ReferencePhotosPage), findsNothing);
      expect(find.text('Root'), findsOneWidget);
    },
  ),

  // --- Trip Suitcase: Plan Trip Outfits ---
  _Entry(
    name: 'TripSuitcasePage._generatePlan',
    overrides: [
      garmentsProvider.overrideWith(() => _FakeGarments(_closet)),
      outfitsProvider.overrideWith(_FakeOutfits.new),
    ],
    open: (tester, root) =>
        _pushPage(tester, root, TripSuitcasePage(trip: _trip())),
    trigger: (tester) async {
      await tester.tap(find.text('Plan Trip Outfits'));
      await tester.pump();
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'POST' && r.url.path.endsWith('/outfits/generate'),
    okReply: () => jsonResponse(
      envelope(
        _tripCollection(
          outfits: [
            {
              'id': 1,
              'source': 'suggested',
              'garments': [_tee, _jeans, _sneakers],
            },
          ],
        ),
      ),
    ),
    otherReply: (r) {
      final path = r.url.path;
      if (path.endsWith('/trip_plans/7/outfits') ||
          path.endsWith('/trip_plans/7/outfits/sync')) {
        return jsonResponse(envelope(_tripCollection()));
      }
      if (path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({'overall_advice': null, 'categories': <Object>[]}),
        );
      }
      return null;
    },
    failure: find.text('Failed to generate outfit plan'),
    unchanged: (tester, b) async {
      expect(find.byType(TripSuitcasePage), findsOneWidget, reason: 'no pop');
      final detail = ProviderScope.containerOf(
        tester.element(find.byType(TripSuitcasePage)),
      ).read(tripDetailProvider(7)).value;
      expect(detail?.outfits ?? const [], isEmpty);
      expect(find.textContaining('AI outfit'), findsNothing);
      expect(b.ownSends, 1);
    },
    succeeded: (tester, b) async {
      expect(find.byType(TripSuitcasePage), findsNothing);
      expect(find.text('Root'), findsOneWidget);
    },
  ),
];

void main() {
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
    GarmentService().clearGarmentCache();
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Taps every dialog's dismiss button, top first, so a failed assertion
  /// can't leave AuthExpiredHandler's guard held.
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
      late _Backend backend;

      Future<void> run(Future<void> Function() body) {
        backend = _Backend(e);
        return http.runWithClient(body, backend.client);
      }

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
        await tester.pump();
        await e.open(tester, root);
        await e.trigger(tester);
        expect(
          backend.heldCount,
          1,
          reason: 'its AI call is in flight: ${backend.sent}',
        );
      }

      Future<void> land(WidgetTester tester, http.Response res) async {
        backend.release(res);
        if (e.usesIo) await _driveIo(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
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

      testWidgets('session expired meanwhile: no failure or Retry over '
          'Session Expired; nothing applied, nothing more sent', (
        tester,
      ) async {
        await run(() async {
          await start(tester);
          unawaited(AuthExpiredHandler.handle(root));
          await tester.pump();
          await tester.pump();
          expect(_sessionExpired, findsOneWidget);

          await land(tester, e.okReply());
          final shown = {
            'failure': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'sessionExpired': _sessionExpired.evaluate().length,
            'overlay': _overlay.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
          };
          try {
            await e.unchanged(tester, backend);
          } finally {
            await closeDialogs(tester);
          }
          expect(shown, {
            'failure': 0,
            'retry': 0,
            'sessionExpired': 1,
            'overlay': 0,
            'login': 0,
          });
        });
      });

      testWidgets('sign-out meanwhile: nothing shown over the login page', (
        tester,
      ) async {
        await run(() async {
          await start(tester);
          await signOutTo(const LoginPage());
          await tester.pump();
          await land(tester, e.okReply());
          await tester.pump(const Duration(seconds: 1));
          while (tester.takeException() != null) {}

          final shown = {
            'failure': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'dialogs': find.byType(AppDialog).evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'failure': 0, 'retry': 0, 'dialogs': 0, 'login': 1});
        });
      });

      testWidgets('a reply after the page is gone touches nothing', (
        tester,
      ) async {
        await run(() async {
          await start(tester);
          await signOutTo(const Scaffold(body: Text('Signed out')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await land(tester, e.okReply());

          expect(tester.takeException(), isNull);
          expect(find.text('Signed out'), findsOneWidget);
          expect(find.byType(AppDialog), findsNothing);
        });
      });

      testWidgets("the same session's 500 keeps its error"
          '${e.hasRetry ? ' and Retry' : ''}', (tester) async {
        await run(() async {
          await start(tester);
          await land(tester, jsonResponse(envelope(null), status: 500));

          final shown = {
            'failure': e.failure.evaluate().isNotEmpty,
            'retry': _retry.evaluate().isNotEmpty,
            'overlay': _overlay.evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'failure': true, 'retry': e.hasRetry, 'overlay': 0});
        });
      });

      testWidgets("the same session's own expiry goes to Session Expired", (
        tester,
      ) async {
        await run(() async {
          await start(tester);
          await land(tester, http.Response('{}', 401));

          final shown = {
            'failure': e.failure.evaluate().length,
            'sessionExpired': _sessionExpired.evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'failure': 0, 'sessionExpired': 1});
        });
      });

      testWidgets('one session, success: the result is applied and loading '
          'clears', (tester) async {
        await run(() async {
          await start(tester);
          await land(tester, e.okReply());
          await e.succeeded(tester, backend);
          expect(e.failure, findsNothing);
          await closeDialogs(tester);
        });
      });
    });
  }
}
