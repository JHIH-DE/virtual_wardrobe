import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/wardrobe/outfit_details_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';

// Finding #1: a request still in flight when its session ends answers with
// SessionChangedException. Shown here through Outfit Details' favourite
// toggle — an optimistic action whose generic catch shows an error dialog.

const _groupId = 741;

Outfit _outfit() => Outfit(
  id: 1,
  groupId: _groupId,
  imageUrl: 'https://img.example/1.png',
  style: const [],
  garmentIds: const [],
);

/// The page's own reads answer at once; its favourite PATCH waits for
/// [release]. Records every request.
class _Backend {
  final requests = <http.Request>[];
  final _patch = Completer<http.Response>();

  void release(http.Response res) => _patch.complete(res);

  MockClient client() => MockClient((req) async {
    requests.add(req);
    if (req.method == 'PATCH') return _patch.future;
    return jsonResponse(envelope({'items': []}));
  });

  bool get refreshed => requests.any((r) => r.url.path.endsWith('/refresh'));
}

final _sessionExpired = find.text('Session Expired');
final _favoriteFailed = find.text('Failed to update favorite');

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

  /// A fresh LoginPage's Google-button image fails to load in tests;
  /// unrelated to what is checked here.
  void drainLoginPageErrors(WidgetTester tester) {
    while (tester.takeException() != null) {}
  }

  /// Closes Session Expired, so the handler's static guard is released for
  /// the next test.
  Future<void> dismissSessionExpired(WidgetTester tester) async {
    await tester.tap(find.byKey(AppDialog.dismissButtonKey).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    drainLoginPageErrors(tester);
  }

  testWidgets('session expired while the favourite PATCH is in flight: only '
      'Session Expired shows, no error dialog over it', (tester) async {
    final backend = _Backend();
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // Another request of A's came back unrecoverable; its page handled it.
      final context = tester.element(find.byType(OutfitDetailsPage));
      unawaited(AuthExpiredHandler.handle(context));
      // The handler's dedupe: a second report changes nothing.
      unawaited(AuthExpiredHandler.handle(context));
      await tester.pump();
      await tester.pump();
      expect(_sessionExpired, findsOneWidget);

      backend.release(http.Response('{}', 401));
      await tester.pump();
      await tester.pump();

      expect(_favoriteFailed, findsNothing);
      expect(_sessionExpired, findsOneWidget);
      expect(backend.refreshed, isFalse);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await dismissSessionExpired(tester);
      expect(find.byType(LoginPage), findsOneWidget);
    }, backend.client);
  });

  testWidgets('sign-out while the favourite PATCH is in flight: no error '
      'dialog over the login page', (tester) async {
    final backend = _Backend();
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // What Settings' Log out does after its confirm.
      final navigator = Navigator.of(
        tester.element(find.byType(OutfitDetailsPage)),
      );
      await clearSignedInSession();
      unawaited(
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        ),
      );
      await tester.pump();
      // The reply lands while the outgoing page is still mounted.
      backend.release(jsonResponse(envelope(null)));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      drainLoginPageErrors(tester);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(_favoriteFailed, findsNothing);
      expect(find.text('Error'), findsNothing);
    }, backend.client);
  });

  testWidgets("A → B: A's late reply leaves B's screen and tokens alone", (
    tester,
  ) async {
    final backend = _Backend();
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      final navigator = Navigator.of(
        tester.element(find.byType(OutfitDetailsPage)),
      );
      await clearSignedInSession();
      unawaited(
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      drainLoginPageErrors(tester);

      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      unawaited(
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text("B's home")),
          ),
          (_) => false,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      // B can only sign in after A's routes are gone.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(OutfitDetailsPage, skipOffstage: false), findsNothing);

      backend.release(http.Response('{}', 401));
      await tester.pump();
      await tester.pump();

      expect(find.text("B's home"), findsOneWidget);
      expect(_favoriteFailed, findsNothing);
      expect(_sessionExpired, findsNothing);
      expect(backend.refreshed, isFalse);
      expect(await AuthStorage.getAccessToken(), 'access-B');
      expect(await AuthStorage.getRefreshToken(), 'refresh-B');
    }, backend.client);
  });

  testWidgets('a real failure in the current session still shows the error '
      'and rolls back', (tester) async {
    final backend = _Backend();
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      backend.release(jsonResponse(envelope(null), status: 500));
      await tester.pump();
      await tester.pump();

      expect(_favoriteFailed, findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    }, backend.client);
  });

  testWidgets("the current session's own expiry still goes to Session "
      'Expired', (tester) async {
    final backend = _Backend();
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // 401, and the refresh (same mock) is not a 200: unrecoverable.
      backend.release(http.Response('{}', 401));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(_sessionExpired, findsOneWidget);
      expect(_favoriteFailed, findsNothing);
      await dismissSessionExpired(tester);
    }, backend.client);
  });
}
