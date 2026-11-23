import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/wardrobe/garment_details_page.dart';
import 'package:uwearis/features/pages/wardrobe/outfit_details_page.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/garment/garment_detail_dialog.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';
import 'package:uwearis/data/outfit_group.dart';

// Finding #1, batch A1-a: Outfit / Garment Details actions whose reply
// lands after their session ended get SessionChangedException. Each entry
// point runs the same five scenarios; the session-ended ones must show no
// error, no Retry, no navigation, and leave the optimistic UI rolled back.

/// Records the writes this batch must not make after its session ended.
final _outfitWrites = <String>[];

class _FakeOutfits extends OutfitsNotifier {
  _FakeOutfits(this._seed);
  final List<Outfit> _seed;

  @override
  Future<List<OutfitGroup>> build() async =>
      _seed.map(singleVersionGroup).toList();

  @override
  Future<void> refresh() async => _outfitWrites.add('refresh');

  @override
  void removeGroup(int groupId) {
    _outfitWrites.add('removeGroup $groupId');
    super.removeGroup(groupId);
  }

  @override
  void updateGroupName(int groupId, {required String name}) {
    _outfitWrites.add('updateGroupName $groupId');
    super.updateGroupName(groupId, name: name);
  }
}

Map<String, dynamic> _versionJson(int id, int groupId, {String? name}) => {
  'outfit_id': id,
  'id': id,
  'group_id': groupId,
  'name': ?name,
  'result_image_url': 'https://img.example/$id.png',
};

Map<String, dynamic> _garmentJson(int id) => {
  'id': id,
  'name': 'Denim Jacket',
  'category': 'Outer',
  'sub_category': 'Denim jacket',
  'upload_url': '',
  'object_name': '',
  'image_url': '',
  'is_deleted': false,
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
    required this.rolledBack,
    this.overrides = const [],
    this.groupVersions = const {},
  });

  final String name;

  /// Opens the page (or dialog) from Root's context.
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

  /// GET /outfit/{groupId} answers.
  final Map<int, List<Map<String, dynamic>>> groupVersions;
}

/// Holds the entry's own request until [release]; the rest answers at once.
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
    requests.add('${req.method} ${req.url.path} ${req.body}');
    if (entry.isOwnRequest(req)) {
      final c = Completer<http.Response>();
      _held.add(c);
      return c.future;
    }
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    for (final MapEntry(key: groupId, value: versions)
        in entry.groupVersions.entries) {
      if (req.method == 'GET' && path.endsWith('/outfit/$groupId')) {
        return jsonResponse(envelope({'outfits': versions}));
      }
    }
    return jsonResponse(envelope({'items': <Object>[]}));
  });
}

final _sessionExpired = find.text('Session Expired');
final _retry = find.text('Retry');

/// Past sheet / dialog / route transitions. The pages keep an image
/// animation running, so pumpAndSettle never settles.
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

Future<void> _tapMenu(WidgetTester tester, IconData icon, String item) async {
  await tester.tap(find.byIcon(icon));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text(item));
  await tester.pump(const Duration(milliseconds: 500));
}

Outfit _outfit(int groupId, {int id = 1, String? name, List<String>? style}) =>
    Outfit(
      id: id,
      groupId: groupId,
      name: name,
      imageUrl: 'https://img.example/$id.png',
      style: style ?? const [],
      garmentIds: const [],
    );

const _savedGarment = Garment(
  id: 7101,
  name: 'Oxford Shirt',
  category: GarmentCategory.top,
  subCategory: 'Shirt',
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
);

List<Outfit> _outfitsIn(ProviderContainer c) =>
    outfitGroupCovers(c.read(outfitsProvider).value ?? const []);

/// No removal or rename reached My Outfits.
void _expectNoOutfitWrites(ProviderContainer c) {
  expect(
    _outfitWrites.where((w) => !w.startsWith('refresh')),
    isEmpty,
    reason: 'provider writes',
  );
  expect(_outfitsIn(c).map((o) => o.id), [1], reason: 'My Outfits kept');
}

final _entries = <_Entry>[
  _Entry(
    name: 'OutfitDetailsPage._saveTags',
    overrides: [
      outfitsProvider.overrideWith(() => _FakeOutfits(const [])),
      dailyOutfitProvider.overrideWith(
        () => SeededDailyOutfitNotifier(const []),
      ),
    ],
    open: (tester, root) => _pushPage(
      tester,
      root,
      OutfitDetailsPage(outfit: _outfit(901, style: ['street'])),
    ),
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.sell_outlined));
      await _settle(tester);
      await tester.tap(find.text('Classic'));
      await _settle(tester);
      await tester.tapAt(const Offset(10, 10)); // closing the sheet saves
      await _settle(tester);
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/outfit/901/1'),
    okReply: () => jsonResponse(envelope({'id': 1, 'group_id': 901})),
    failure: find.text("Couldn't update this outfit. Please try again."),
    rolledBack: (tester, _) {
      expect(find.byType(CategoryTag), findsOneWidget, reason: 'tags');
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
    name: 'OutfitDetailsPage._setCover',
    overrides: [
      outfitsProvider.overrideWith(() => _FakeOutfits(const [])),
      dailyOutfitProvider.overrideWith(
        () => SeededDailyOutfitNotifier(const []),
      ),
    ],
    groupVersions: {
      902: [
        _versionJson(1, 902, name: 'First'),
        _versionJson(2, 902, name: 'Second'),
      ],
    },
    open: (tester, root) async {
      await _pushPage(
        tester,
        root,
        OutfitDetailsPage(outfit: _outfit(902, id: 2, name: 'Second')),
      );
      expect(find.text('First'), findsOneWidget, reason: 'cover title');
    },
    trigger: (tester) async {
      await _tapMenu(tester, Icons.more_horiz, 'Set as Cover');
      expect(find.text('Second'), findsOneWidget, reason: 'optimistic');
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/outfit/902'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text("Couldn't update this outfit. Please try again."),
    rolledBack: (tester, _) {
      expect(find.text('First'), findsOneWidget, reason: 'cover restored');
      expect(find.text('Second'), findsNothing);
    },
  ),
  _Entry(
    name: 'OutfitDetailsPage._deleteThisOutfit',
    overrides: [
      outfitsProvider.overrideWith(() => _FakeOutfits([_outfit(903)])),
      dailyOutfitProvider.overrideWith(
        () => SeededDailyOutfitNotifier(const []),
      ),
    ],
    groupVersions: {
      903: [
        for (final id in [1, 2, 3]) _versionJson(id, 903),
      ],
    },
    open: (tester, root) =>
        _pushPage(tester, root, OutfitDetailsPage(outfit: _outfit(903))),
    trigger: (tester) async {
      await _tapMenu(tester, Icons.more_horiz, 'Delete Version');
      await tester.tap(find.text('Delete').last);
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'DELETE' && r.url.path.endsWith('/outfit/903/1'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text("Couldn't delete this outfit. Please try again."),
    rolledBack: (tester, c) {
      expect(find.text('1 / 3'), findsOneWidget, reason: 'versions kept');
      _expectNoOutfitWrites(c);
    },
  ),
  _Entry(
    name: 'OutfitDetailsPage._confirmThenDeleteGroup',
    overrides: [
      outfitsProvider.overrideWith(() => _FakeOutfits([_outfit(904)])),
      dailyOutfitProvider.overrideWith(
        () => SeededDailyOutfitNotifier(const []),
      ),
    ],
    groupVersions: {
      904: [_versionJson(1, 904)],
    },
    open: (tester, root) =>
        _pushPage(tester, root, OutfitDetailsPage(outfit: _outfit(904))),
    trigger: (tester) async {
      await _tapMenu(tester, Icons.more_vert, 'Delete Outfit');
      await tester.tap(find.text('Delete').last);
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'DELETE' && r.url.path.endsWith('/outfit/904'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text("Couldn't delete this outfit. Please try again."),
    rolledBack: (tester, c) => _expectNoOutfitWrites(c),
  ),
  _Entry(
    name: 'OutfitDetailsPage._leaveNewOutfit',
    overrides: [
      outfitsProvider.overrideWith(() => _FakeOutfits([_outfit(905)])),
      dailyOutfitProvider.overrideWith(
        () => SeededDailyOutfitNotifier(const []),
      ),
    ],
    groupVersions: {
      905: [_versionJson(1, 905)],
    },
    open: (tester, root) => _pushPage(
      tester,
      root,
      OutfitDetailsPage(outfit: _outfit(905), isNew: true),
    ),
    trigger: (tester) async {
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.tap(find.text("Don't Save"));
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'DELETE' && r.url.path.endsWith('/outfit/905'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text("Couldn't delete this outfit. Please try again."),
    rolledBack: (tester, c) => _expectNoOutfitWrites(c),
  ),
  _Entry(
    name: 'OutfitDetailsPage._showRenameDialog',
    overrides: [
      outfitsProvider.overrideWith(() => _FakeOutfits([_outfit(906)])),
      dailyOutfitProvider.overrideWith(
        () => SeededDailyOutfitNotifier(const []),
      ),
    ],
    groupVersions: {
      906: [_versionJson(1, 906)],
    },
    open: (tester, root) =>
        _pushPage(tester, root, OutfitDetailsPage(outfit: _outfit(906))),
    trigger: (tester) async {
      await _tapMenu(tester, Icons.more_vert, 'Rename');
      await tester.enterText(find.byType(TextField).last, 'Renamed');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await _settle(tester);
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/outfit/906'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text("Couldn't update this outfit. Please try again."),
    rolledBack: (tester, c) {
      expect(find.text('Renamed'), findsNothing, reason: 'title unchanged');
      _expectNoOutfitWrites(c);
      expect(c.read(outfitsProvider).value!.single.name, isNull);
    },
  ),
  _Entry(
    name: 'GarmentDetailsPage._toggleFavorite',
    open: (tester, root) => _pushPage(
      tester,
      root,
      const GarmentDetailsPage(initialGarment: _savedGarment),
    ),
    trigger: (tester) async {
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget, reason: 'optimistic');
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/garments/7101'),
    okReply: () => jsonResponse(envelope(_garmentJson(7101))),
    failure: find.text('Failed to update favorite'),
    rolledBack: (tester, _) {
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    },
  ),
  _Entry(
    name: 'GarmentDetailsPage._handleDelete',
    open: (tester, root) => _pushPage(
      tester,
      root,
      const GarmentDetailsPage(initialGarment: _savedGarment),
    ),
    trigger: (tester) async {
      await _tapMenu(tester, Icons.more_vert, 'Delete Garment');
      await tester.tap(find.text('Delete').last);
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'DELETE' && r.url.path.endsWith('/garments/7101'),
    okReply: () => jsonResponse(envelope(null)),
    failure: find.text("Couldn't delete this item. Please try again."),
    rolledBack: (tester, _) {},
  ),
  _Entry(
    name: 'GarmentDetailsPage._saveGarment',
    open: (tester, root) => _pushPage(
      tester,
      root,
      const GarmentDetailsPage(
        initialGarment: Garment(
          name: '',
          category: GarmentCategory.top,
          subCategory: '',
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
        ),
        initialAnalysisData: {
          'name': 'Tee',
          'category': 'Top',
          'sub_category': 'T-Shirt',
        },
      ),
    ),
    trigger: (tester) async {
      await tester.enterText(find.byType(TextField).first, 'New Tee');
      await tester.pump();
      await tester.tap(find.text('Add to Closet'));
      await tester.pump();
      // The bar fades out while uploading.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Add to Closet'), findsNothing, reason: 'uploading');
    },
    isOwnRequest: (r) => r.url.path.endsWith('/garments/init-upload'),
    okReply: () => jsonResponse(
      envelope({'upload_url': 'https://example.com/u', 'object_name': 'o'}),
    ),
    failure: find.text("Couldn't save this item. Please try again."),
    rolledBack: (tester, _) {
      expect(find.text('Add to Closet'), findsOneWidget, reason: 'uploading');
    },
  ),
  _Entry(
    name: 'GarmentDetailDialog._restore',
    open: (tester, root) async {
      unawaited(
        GarmentDetailDialog.show(
          root,
          const Garment(
            id: 7102,
            name: 'Denim Jacket',
            category: GarmentCategory.outer,
            subCategory: 'Denim jacket',
            uploadUrl: '',
            objectName: '',
            imageUrl: '',
            isDeleted: true,
          ),
        ),
      );
      await _settle(tester);
    },
    trigger: (tester) async {
      await tester.tap(find.text('Add Back to Closet'));
      await tester.pump();
    },
    isOwnRequest: (r) =>
        r.method == 'PATCH' && r.url.path.endsWith('/garments/7102'),
    okReply: () => jsonResponse(envelope(_garmentJson(7102))),
    failure: find.text('Failed to restore this item'),
    rolledBack: (tester, _) {
      expect(find.byType(GarmentDetailDialog), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Add Back to Closet'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNotNull, reason: '_restoring reset');
    },
  ),
];

void main() {
  setUp(() {
    _outfitWrites.clear();
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
        if (e.overrides.isNotEmpty) {
          // Loaded and kept alive, as My Outfits keeps it.
          final sub = container.listen(outfitsProvider, (_, _) {});
          addTearDown(sub.close);
          await tester.pump();
          expect(container.read(outfitsProvider).hasValue, isTrue);
        }
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
