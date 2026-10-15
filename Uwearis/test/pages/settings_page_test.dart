import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/features/pages/login_page.dart';
import 'package:uwearis/features/pages/settings_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUp(() {
    setUpFakeAuth();
    SharedPreferences.setMockInitialValues({});
  });

  // Answers profileProvider's GET /users/me.
  Future<void> runWithProfile(Future<void> Function() body) {
    return http.runWithClient(
      body,
      () => MockClient(
        (_) async => jsonResponse(
          envelope({'name': 'Test User', 'email': 'test@example.com'}),
        ),
      ),
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('tapping Logout asks for confirmation instead of logging out '
      'immediately', (tester) async {
    await runWithProfile(() async {
      useTallSurface(tester);
      await pumpApp(tester, const SettingsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  testWidgets('Cancel on the logout confirmation keeps the user on Settings', (
    tester,
  ) async {
    await runWithProfile(() async {
      useTallSurface(tester);
      await pumpApp(tester, const SettingsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  testWidgets(
    'confirming Logout clears any cached closet-analysis results — this '
    'app has no per-user cache key, so wiping it at the one point a '
    'session ends is what stops the next signed-in user on this device '
    'from seeing it',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'closet_analysis_4242': jsonEncode({
          'analysis': {
            'versatility': {'level': 8, 'label': 'Versatile'},
            'outfit_ideas': <Object?>[],
            'similar_garments': <Object?>[],
          },
          'analyzed_at': DateTime.now().toIso8601String(),
        }),
      });
      expect(await GarmentService().cachedClosetAnalysis(4242), isNotNull);

      await runWithProfile(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Logout').last);
        await tester.pump();
        // LoginPage's Google-button network image fails in flutter_test and
        // its fallback overflows; unrelated to this test, so drain them.
        while (tester.takeException() != null) {}
      });

      expect(await GarmentService().cachedClosetAnalysis(4242), isNull);
    },
  );

  group('perceived temperature offset', () {
    http.Client client(List<http.Request> patches, {int patchStatus = 200}) =>
        MockClient((request) async {
          if (request.method == 'PATCH') {
            patches.add(request);
            return patchStatus == 200
                ? jsonResponse(envelope({'name': 'Test User'}))
                : jsonResponse(envelope(null), status: patchStatus);
          }
          return jsonResponse(
            envelope({'name': 'Test User', 'email': 'test@example.com'}),
          );
        });

    testWidgets('shows the locally cached offset', (tester) async {
      SharedPreferences.setMockInitialValues({'temperature_offset': -2});
      await runWithProfile(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();

        expect(find.text('Perceived Temperature Offset'), findsOneWidget);
        expect(find.text('-2°C'), findsOneWidget);
      });
    });

    testWidgets('picking a value PATCHes it and caches it locally', (
      tester,
    ) async {
      final patches = <http.Request>[];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();
        expect(find.text('0°C'), findsOneWidget);

        await tester.tap(find.text('Perceived Temperature Offset'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+2°C'));
        await tester.pumpAndSettle();

        expect(patches, hasLength(1));
        final body = jsonDecode(patches.single.body) as Map<String, dynamic>;
        expect(body, {'temperature_offset_c': 2});
        expect(find.text('+2°C'), findsOneWidget);
      }, () => client(patches));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('temperature_offset'), 2);
    });

    testWidgets('a failed save rolls back and offers Retry', (tester) async {
      final patches = <http.Request>[];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Perceived Temperature Offset'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+2°C'));
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('+2°C'), findsNothing);
        expect(find.text('0°C'), findsOneWidget);
      }, () => client(patches, patchStatus: 500));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('temperature_offset'), isNull);
    });

    testWidgets('Settings no longer links to a Lifestyle page', (tester) async {
      await runWithProfile(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();

        expect(find.text('Lifestyle'), findsNothing);
      });
    });
  });

  group('tier badge', () {
    Future<void> pumpWithTier(WidgetTester tester, String? tier) {
      return http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpApp(tester, const SettingsPage());
          await tester.pumpAndSettle();
        },
        () => MockClient(
          (_) async => jsonResponse(
            envelope({
              'name': 'Test User',
              'email': 'test@example.com',
              'tier': ?tier,
            }),
          ),
        ),
      );
    }

    testWidgets('tier_1 shows Gold', (tester) async {
      await pumpWithTier(tester, 'tier_1');
      expect(find.text('Gold'), findsOneWidget);
    });

    testWidgets('tier_2 shows Silver', (tester) async {
      await pumpWithTier(tester, 'tier_2');
      expect(find.text('Silver'), findsOneWidget);
    });

    testWidgets('a missing tier falls back to Bronze', (tester) async {
      await pumpWithTier(tester, null);
      expect(find.text('Bronze'), findsOneWidget);
    });
  });
}
