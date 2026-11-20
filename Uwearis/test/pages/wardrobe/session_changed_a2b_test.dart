import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/settings/personal_details_page.dart';
import 'package:uwearis/features/pages/settings/reference_photos_page.dart';
import 'package:uwearis/features/pages/wardrobe/create_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/garment_details_page.dart';
import 'package:uwearis/features/widgets/common/fields/labeled_field.dart';
import 'package:uwearis/features/widgets/common/fields/picker_field.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';

// Finding #1, batch A2 (second): a product-type picker, the adjust-details
// sheet and two profile pages wait on a provider's load. A load that ends
// after its session did fails with SessionChangedException; each entry
// point runs the same five scenarios as the earlier batches.

class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._seed);
  final List<Garment> _seed;

  @override
  Future<List<Garment>> build() async => _seed;

  @override
  Future<void> refresh() async => state = AsyncData(_seed);
}

const _tee = Garment(
  id: 1,
  garmentId: 1,
  name: 'Tee',
  category: GarmentCategory.top,
  subCategory: 'T-shirt',
  adjustmentOptions: ['sleeve'],
  uploadUrl: '',
  objectName: '',
);

const _savedShirt = Garment(
  id: 7201,
  name: 'Oxford Shirt',
  category: GarmentCategory.top,
  subCategory: 'Shirt',
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
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
    required this.unchanged,
    this.overrides = const [],
  });

  final String name;
  final Future<void> Function(WidgetTester tester, BuildContext root) open;
  final Future<void> Function(WidgetTester tester) trigger;
  final bool Function(http.Request request) isOwnRequest;
  final http.Response Function() okReply;

  /// The error copy a same-session failure shows.
  final Finder failure;

  /// After the session ended: nothing opened, nothing written, in-flight
  /// state reset.
  final void Function(WidgetTester tester) unchanged;
  final List<Override> overrides;
}

class _Backend {
  _Backend(this.entry);
  final _Entry entry;
  final _held = <Completer<http.Response>>[];
  http.Response? _reply;
  final requests = <String>[];

  int get heldCount => _held.length;

  /// How often the entry's own request was sent: a Retry or an invalidate
  /// would send it again.
  int ownSends = 0;

  /// Answers the held request, and any retry of it, with [res].
  void release(http.Response res) {
    _reply = res;
    for (final c in _held) {
      if (!c.isCompleted) c.complete(res);
    }
  }

  MockClient client() => MockClient((req) async {
    requests.add('${req.method} ${req.url}');
    if (entry.isOwnRequest(req)) {
      ownSends++;
      final reply = _reply;
      if (reply != null) return reply;
      final c = Completer<http.Response>();
      _held.add(c);
      return c.future;
    }
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (path.endsWith('/garments/sub-categories')) {
      return jsonResponse(envelope(<Object>[]));
    }
    return jsonResponse(envelope({'items': <Object>[]}));
  });
}

late _Backend _backend;

final _sessionExpired = find.text('Session Expired');
final _retry = find.text('Retry');
final _sheet = find.byType(BottomSheet);

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

final _accountA = jsonResponse(
  envelope({
    'name': 'Account A',
    'gender': 'Female',
    'location': 'Taipei',
    'birthday': '1990-01-01',
  }),
);

final _entries = <_Entry>[
  _Entry(
    name: 'GarmentDetailsPage._openSubCategoryPicker',
    open: (tester, root) => _pushPage(
      tester,
      root,
      const GarmentDetailsPage(initialGarment: _savedShirt),
    ),
    trigger: (tester) async {
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(LabeledField, 'PRODUCT TYPE'),
          matching: find.byType(PickerField),
        ),
      );
      await tester.pump();
    },
    // The picker's (gender-filtered) list; the labels' full list isn't held.
    isOwnRequest: (r) =>
        r.url.path.endsWith('/garments/sub-categories') &&
        !r.url.queryParameters.containsKey('gender'),
    okReply: () => jsonResponse(envelope(<Object>[])),
    failure: find.text("Couldn't load the product types. Please try again."),
    unchanged: (tester) {
      expect(_sheet, findsNothing, reason: 'no picker opened');
      expect(_backend.ownSends, 1, reason: 'no retry / invalidate');
    },
  ),
  _Entry(
    name: 'CreateOutfitPage._openAdjustDetailsSheet',
    overrides: [
      garmentsProvider.overrideWith(() => _FakeGarments(const [_tee])),
    ],
    open: (tester, root) => _pushPage(
      tester,
      root,
      const CreateOutfitPage(initialGarments: [_tee]),
    ),
    trigger: (tester) async {
      // Before the table loads, the garment's own list offers the action.
      await tester.drag(find.text('Tee'), const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pump();
    },
    isOwnRequest: (r) => r.url.path.endsWith('/outfit/adjustment-options'),
    okReply: () => jsonResponse(envelope({'items': <Object>[]})),
    failure: find.text("Couldn't load the styling options. Please try again."),
    unchanged: (tester) {
      expect(_sheet, findsNothing, reason: 'no sheet opened');
      expect(find.text('Sleeves'), findsNothing);
      expect(_backend.ownSends, 1, reason: 'no retry / invalidate');
    },
  ),
  _Entry(
    name: 'PersonalDetailsPage._loadProfile',
    open: (tester, root) =>
        _pushPage(tester, root, const PersonalDetailsPage()),
    trigger: (tester) async => tester.pump(),
    isOwnRequest: (r) => r.method == 'GET' && r.url.path.endsWith('/users/me'),
    okReply: () => _accountA,
    failure: find.text('Failed to Load'),
    unchanged: (tester) {
      expect(find.text('Account A'), findsNothing, reason: 'no old profile');
      final gender = tester.widget<PickerField>(
        find.descendant(
          of: find.widgetWithText(LabeledField, 'GENDER'),
          matching: find.byType(PickerField),
        ),
      );
      expect(gender.onTap, isNotNull, reason: 'loading cleared');
    },
  ),
  _Entry(
    name: 'ReferencePhotosPage._loadProfile',
    open: (tester, root) =>
        _pushPage(tester, root, const ReferencePhotosPage()),
    trigger: (tester) async => tester.pump(),
    isOwnRequest: (r) => r.method == 'GET' && r.url.path.endsWith('/users/me'),
    okReply: () => _accountA,
    failure: find.text('Failed to Load'),
    unchanged: (tester) {
      expect(find.byType(ReferencePhotosPage), findsOneWidget);
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
        ).listen(profileProvider, (_, _) {});
        addTearDown(sub.close);
        await tester.pump();
        await e.open(tester, root);
        await e.trigger(tester);
        expect(
          _backend.heldCount,
          1,
          reason: 'its load is in flight: ${_backend.requests}',
        );
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

      testWidgets('session expired meanwhile: no error or Retry over Session '
          'Expired, nothing opened or written', (tester) async {
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
            'login': find.byType(LoginPage).evaluate().length,
          };
          try {
            e.unchanged(tester);
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
          _backend.release(e.okReply());
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          while (tester.takeException() != null) {}

          final shown = {
            'error': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
            'sheet': _sheet.evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'retry': 0, 'login': 1, 'sheet': 0});
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
          expect(_sheet, findsNothing);
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

          final shown = e.failure.evaluate().length;
          await closeDialogs(tester);
          expect(shown, 1);
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
