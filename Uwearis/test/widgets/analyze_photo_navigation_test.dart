import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/image_edit_result.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/garment/garment_upload_helper.dart';

import '../helpers/mock_http.dart';
import '../helpers/scripted_auth_storage.dart';
import '../helpers/widget_harness.dart';

// C2: analyzePhoto closes its loading overlay after an await. Closing
// "whatever is on top" can close Session Expired or the login page instead,
// and a reply from an ended session must not ask "retry?".

/// The multipart upload reads the file for real, which only advances
/// outside fake async; each step's callback then needs a pump.
Future<void> _driveIo(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

/// analyze-instant: each request waits for [release], then answers
/// [reply]; the refresh endpoint refuses.
class _Backend {
  final _gates = <Completer<void>>[];
  http.Response Function() reply = () => jsonResponse(
    envelope({
      'metadata': {'category': 'Top', 'sub_category': 'Tee'},
      'processed_image_base64': '',
    }),
  );

  int get analyses => _gates.length;

  void release() {
    for (final g in _gates) {
      if (!g.isCompleted) g.complete();
    }
  }

  MockClient client() => MockClient((req) async {
    if (req.url.path.endsWith('/auth/refresh')) {
      return http.Response('{}', 401);
    }
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    return reply();
  });
}

final _overlay = find.byType(LoadingOverlay);
final _sessionExpired = find.text('Session Expired');
final _retryPrompt = find.text("Couldn't analyze this photo");
final _page = find.text('Analyze', skipOffstage: false);

void main() {
  late File photo;
  late BuildContext page;
  late _Backend backend;

  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
    backend = _Backend();
    final dir = Directory.systemTemp.createTempSync('analyze_photo_nav');
    photo = File('${dir.path}/photo.jpg')..writeAsBytesSync([0xFF, 0xD8]);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  /// Root → a page whose button starts the analysis; the analysis is left
  /// in flight. Returns its result.
  Future<Future<ImageEditResult?>> start(WidgetTester tester) async {
    late Future<ImageEditResult?> result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (pageContext) {
                page = pageContext;
                return Scaffold(
                  body: TextButton(
                    onPressed: () => result = GarmentUploadHelper.analyzePhoto(
                      pageContext,
                      photo.path,
                    ),
                    child: const Text('Analyze'),
                  ),
                );
              },
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze'));
    await tester.pump();
    await _driveIo(tester);
    expect(_overlay, findsOneWidget);
    expect(backend.analyses, 1);
    return result;
  }

  /// The reply lands; a route removed from under another leaves on a later
  /// frame.
  Future<void> land(WidgetTester tester) async {
    backend.release();
    await _driveIo(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> signOutTo(Widget next) async {
    final navigator = Navigator.of(page);
    await clearSignedInSession();
    unawaited(
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
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
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    while (tester.takeException() != null) {}
  }

  testWidgets('session expired while analyzing: the overlay goes, Session '
      'Expired stays, no "retry?", nothing sent again', (tester) async {
    await http.runWithClient(() async {
      final result = await start(tester);
      ImageEditResult? value = ImageEditResult(imagePath: 'unset');
      unawaited(result.then((r) => value = r));

      unawaited(AuthExpiredHandler.handle(page));
      await tester.pump();
      await tester.pump();
      expect(_sessionExpired, findsOneWidget);

      await land(tester);
      final shown = {
        'overlay': _overlay.evaluate().length,
        'sessionExpired': _sessionExpired.evaluate().length,
        'retryPrompt': _retryPrompt.evaluate().length,
        'page': _page.evaluate().length,
        'login': find.byType(LoginPage).evaluate().length,
        'analyses': backend.analyses,
      };
      await closeDialogs(tester);
      expect(shown, {
        'overlay': 0,
        'sessionExpired': 1,
        'retryPrompt': 0,
        'page': 1,
        'login': 0,
        'analyses': 1,
      });
      expect(value, isNull);
    }, backend.client);
  });

  testWidgets('sign-out while analyzing: the late reply pops nothing off the '
      'login page and asks nothing', (tester) async {
    await http.runWithClient(() async {
      await start(tester);
      await signOutTo(const LoginPage());
      await tester.pump();
      await land(tester);
      await tester.pump(const Duration(seconds: 1));
      while (tester.takeException() != null) {}

      final shown = {
        'login': find.byType(LoginPage).evaluate().length,
        'retryPrompt': _retryPrompt.evaluate().length,
        'dialogs': find.byType(AppDialog).evaluate().length,
        'overlay': _overlay.evaluate().length,
      };
      await closeDialogs(tester);
      expect(shown, {'login': 1, 'retryPrompt': 0, 'dialogs': 0, 'overlay': 0});
    }, backend.client);
  });

  testWidgets('a reply after the page and stack are gone touches nothing', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await start(tester);
      await signOutTo(const Scaffold(body: Text('Signed out')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await land(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Signed out'), findsOneWidget);
      expect(find.byType(AppDialog), findsNothing);
    }, backend.client);
  });

  testWidgets("its own unrecoverable 401: the overlay goes and Session "
      'Expired shows, over the page it came from', (tester) async {
    backend.reply = () => http.Response('{}', 401);
    await http.runWithClient(() async {
      await start(tester);
      await land(tester);
      await tester.pump();

      final shown = {
        'overlay': _overlay.evaluate().length,
        'sessionExpired': _sessionExpired.evaluate().length,
        'retryPrompt': _retryPrompt.evaluate().length,
        'page': _page.evaluate().length,
      };
      await closeDialogs(tester);
      expect(shown, {
        'overlay': 0,
        'sessionExpired': 1,
        'retryPrompt': 0,
        'page': 1,
      });
    }, backend.client);
  });

  testWidgets('a 500 still clears the overlay and asks "retry?" over the '
      'page', (tester) async {
    backend.reply = () => jsonResponse(envelope(null), status: 500);
    await http.runWithClient(() async {
      await start(tester);
      await land(tester);

      expect(_overlay, findsNothing);
      expect(_retryPrompt, findsOneWidget);
      expect(_page, findsOneWidget);
      await closeDialogs(tester);
    }, backend.client);
  });

  testWidgets('success closes only the overlay and returns the result', (
    tester,
  ) async {
    await http.runWithClient(() async {
      final result = await start(tester);
      ImageEditResult? value;
      unawaited(result.then((r) => value = r));
      await land(tester);

      expect(_overlay, findsNothing);
      expect(find.text('Analyze'), findsOneWidget);
      expect(value?.analysisData?['sub_category'], 'Tee');
    }, backend.client);
  });

  testWidgets('Cancel closes only the overlay; a session expiring before the '
      'reply lands changes nothing more', (tester) async {
    await http.runWithClient(() async {
      final result = await start(tester);
      ImageEditResult? value = ImageEditResult(imagePath: 'unset');
      unawaited(result.then((r) => value = r));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_overlay, findsNothing);
      expect(find.text('Analyze'), findsOneWidget);
      expect(value, isNull);

      unawaited(AuthExpiredHandler.handle(page));
      await tester.pump();
      await tester.pump();
      await land(tester);

      final shown = {
        'sessionExpired': _sessionExpired.evaluate().length,
        'retryPrompt': _retryPrompt.evaluate().length,
        'page': _page.evaluate().length,
      };
      await closeDialogs(tester);
      expect(shown, {'sessionExpired': 1, 'retryPrompt': 0, 'page': 1});
    }, backend.client);
  });
}
