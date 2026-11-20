import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/settings/my_outfit_profile_page.dart';
import 'package:uwearis/features/pages/settings/personal_details_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';

import '../helpers/mock_http.dart';
import '../helpers/scripted_auth_storage.dart';
import '../helpers/widget_harness.dart';

// Finding #1, B1 / B2: an auto-save whose reply lands after its session
// ended fails with SessionChangedException. The shared prompts must not
// put "Couldn't save" + Retry, or "You have unsaved changes", over
// Session Expired or the login page.

/// The profile backend. A PATCH is applied, then waits for [release] when
/// [hold] is set; its reply is [patchReply] when set.
class _Backend {
  final patches = <Map<String, dynamic>>[];
  bool hold = false;
  final _held = <Completer<void>>[];
  http.Response? patchReply;
  num offset = -1;

  void release() {
    for (final c in _held) {
      if (!c.isCompleted) c.complete();
    }
  }

  int get heldCount => _held.length;

  MockClient client() => MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (path.endsWith('/users/me')) {
      if (req.method == 'PATCH') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body.containsKey('locale')) {
          return jsonResponse(envelope({'name': 'User'}));
        }
        patches.add(body);
        if (body['temperature_offset_c'] case final num v) offset = v;
        if (hold) {
          final c = Completer<void>();
          _held.add(c);
          await c.future;
        }
        final reply = patchReply;
        if (reply != null) return reply;
      }
      return jsonResponse(
        envelope({'name': 'User', 'temperature_offset_c': offset}),
      );
    }
    return jsonResponse(envelope({'items': <Object>[]}));
  });
}

final _failed = find.text("Couldn't save your profile. Please try again.");
final _retry = find.text('Retry');
final _unsaved = find.text('You have unsaved changes');
final _sessionExpired = find.text('Session Expired');
final _plus = find.byIcon(Icons.add_circle_outline);

void main() {
  late BuildContext root;
  late _Backend backend;

  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
    backend = _Backend();
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> open(WidgetTester tester, Widget page) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          root = context;
          return const Scaffold(body: Text('Root'));
        },
      ),
      retry: (_, _) => null,
    );
    final sub = ProviderScope.containerOf(
      root,
    ).listen(profileProvider, (_, _) {});
    addTearDown(sub.close);
    unawaited(Navigator.of(root).push(MaterialPageRoute(builder: (_) => page)));
    await settle(tester);
  }

  /// My Outfit Profile, with a + step's auto-save PATCH held in flight.
  Future<void> stepAndHold(WidgetTester tester) async {
    await open(tester, const MyOutfitProfilePage());
    expect(find.text('-1°C'), findsOneWidget);
    backend.hold = true;
    await tester.tap(_plus);
    await tester.pump();
    expect(backend.heldCount, 1);
  }

  Future<void> expireSessionElsewhere(WidgetTester tester) async {
    unawaited(AuthExpiredHandler.handle(root));
    await tester.pump();
    await tester.pump();
    expect(_sessionExpired, findsOneWidget);
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

  /// Taps every dialog's dismiss button, top first, so a failed assertion
  /// can't leave AuthExpiredHandler's guard held.
  Future<void> closeDialogs(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      final buttons = find.byKey(AppDialog.dismissButtonKey);
      if (buttons.evaluate().isEmpty) break;
      await tester.tap(buttons.last);
      await settle(tester);
    }
    while (tester.takeException() != null) {}
  }

  Map<String, Object> dialogs() => {
    'failed': _failed.evaluate().length,
    'retry': _retry.evaluate().length,
    'unsaved': _unsaved.evaluate().length,
    'sessionExpired': _sessionExpired.evaluate().length,
  };

  group('showAutoSaveErrorDialog', () {
    testWidgets('session expired while saving: no error or Retry over '
        'Session Expired, and nothing is sent again', (tester) async {
      await http.runWithClient(() async {
        await stepAndHold(tester);
        await expireSessionElsewhere(tester);
        backend.release();
        await settle(tester);

        final shown = dialogs();
        await closeDialogs(tester);
        expect(shown, {
          'failed': 0,
          'retry': 0,
          'unsaved': 0,
          'sessionExpired': 1,
        });
      }, backend.client);
      expect(backend.patches, hasLength(1));
    });

    testWidgets("Personal Details' typed change, same: no error or Retry "
        'over Session Expired', (tester) async {
      await http.runWithClient(() async {
        await open(tester, const PersonalDetailsPage());
        backend.hold = true;
        await tester.enterText(find.byType(TextField).first, 'New name');
        // Past the 800ms debounce: the save is sent and held.
        await tester.pump(const Duration(seconds: 1));
        expect(backend.heldCount, 1);

        await expireSessionElsewhere(tester);
        backend.release();
        await settle(tester);

        final shown = dialogs();
        await closeDialogs(tester);
        expect(shown, {
          'failed': 0,
          'retry': 0,
          'unsaved': 0,
          'sessionExpired': 1,
        });
      }, backend.client);
      expect(backend.patches, hasLength(1));
    });

    testWidgets('sign-out while saving: no error over the login page', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await stepAndHold(tester);
        await signOutTo(const LoginPage());
        await tester.pump();
        backend.release();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        while (tester.takeException() != null) {}

        final shown = {
          ...dialogs(),
          'login': find.byType(LoginPage).evaluate().length,
        };
        await closeDialogs(tester);
        expect(shown, {
          'failed': 0,
          'retry': 0,
          'unsaved': 0,
          'sessionExpired': 0,
          'login': 1,
        });
      }, backend.client);
      expect(backend.patches, hasLength(1));
    });

    testWidgets('a reply after the page and its controller are gone shows '
        'nothing', (tester) async {
      await http.runWithClient(() async {
        await stepAndHold(tester);
        await signOutTo(const Scaffold(body: Text('Signed out')));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        backend.release();
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Signed out'), findsOneWidget);
        expect(find.byType(AppDialog), findsNothing);
      }, backend.client);
    });

    testWidgets("the same session's 500 still offers Retry, which saves "
        'again', (tester) async {
      await http.runWithClient(() async {
        await stepAndHold(tester);
        backend.patchReply = jsonResponse(envelope(null), status: 500);
        backend.release();
        await settle(tester);
        expect(_failed, findsOneWidget);
        expect(_retry, findsOneWidget);

        backend
          ..hold = false
          ..patchReply = null;
        await tester.tap(_retry);
        await settle(tester);
        expect(find.byType(AppDialog), findsNothing);
        expect(find.text('0°C'), findsOneWidget);
      }, backend.client);
      expect(backend.patches, hasLength(2));
    });

    testWidgets("the same session's own expiry still goes to Session "
        'Expired', (tester) async {
      await http.runWithClient(() async {
        await stepAndHold(tester);
        backend.patchReply = http.Response('{}', 401);
        backend.release();
        await settle(tester);

        final shown = dialogs();
        await closeDialogs(tester);
        expect(shown, {
          'failed': 0,
          'retry': 0,
          'unsaved': 0,
          'sessionExpired': 1,
        });
      }, backend.client);
    });

    testWidgets('a successful save shows nothing', (tester) async {
      await http.runWithClient(() async {
        await stepAndHold(tester);
        backend.release();
        await settle(tester);

        expect(find.byType(AppDialog), findsNothing);
        expect(find.text('0°C'), findsOneWidget);
      }, backend.client);
      expect(backend.patches, [
        {'temperature_offset_c': 0},
      ]);
    });
  });

  group('confirmLeaveAfterAutoSave', () {
    /// A back while the save is still in flight: leaving waits for it.
    Future<void> leaveWhileSaving(WidgetTester tester) async {
      await stepAndHold(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(MyOutfitProfilePage), findsOneWidget);
    }

    testWidgets('session expired while leaving: no "unsaved changes" over '
        'Session Expired, no save again, no pop', (tester) async {
      await http.runWithClient(() async {
        await leaveWhileSaving(tester);
        await expireSessionElsewhere(tester);
        backend.release();
        await settle(tester);

        final shown = {
          ...dialogs(),
          'page': find.byType(MyOutfitProfilePage).evaluate().length,
          'login': find.byType(LoginPage).evaluate().length,
        };
        await closeDialogs(tester);
        expect(shown, {
          'failed': 0,
          'retry': 0,
          'unsaved': 0,
          'sessionExpired': 1,
          'page': 1,
          'login': 0,
        });
      }, backend.client);
      expect(backend.patches, hasLength(1));
    });

    testWidgets("the same session's 500 while leaving still asks", (
      tester,
    ) async {
      await http.runWithClient(() async {
        await leaveWhileSaving(tester);
        backend.patchReply = jsonResponse(envelope(null), status: 500);
        backend.release();
        await settle(tester);

        final shown = dialogs();
        await closeDialogs(tester);
        expect(shown, {
          'failed': 0,
          'retry': 0,
          'unsaved': 1,
          'sessionExpired': 0,
        });
      }, backend.client);
    });

    testWidgets("the same session's own expiry while leaving still goes to "
        'Session Expired', (tester) async {
      await http.runWithClient(() async {
        await leaveWhileSaving(tester);
        backend.patchReply = http.Response('{}', 401);
        backend.release();
        await settle(tester);

        final shown = dialogs();
        await closeDialogs(tester);
        expect(shown, {
          'failed': 0,
          'retry': 0,
          'unsaved': 0,
          'sessionExpired': 1,
        });
      }, backend.client);
    });

    testWidgets('a successful save while leaving leaves', (tester) async {
      await http.runWithClient(() async {
        await leaveWhileSaving(tester);
        backend.release();
        await settle(tester);

        expect(find.byType(MyOutfitProfilePage), findsNothing);
        expect(find.text('Root'), findsOneWidget);
        expect(find.byType(AppDialog), findsNothing);
      }, backend.client);
    });
  });
}
