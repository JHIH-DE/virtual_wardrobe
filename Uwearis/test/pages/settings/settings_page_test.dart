import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/core/utils/user_acknowledgement.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/settings/my_outfit_profile_page.dart';
import 'package:uwearis/features/pages/settings/settings_page.dart';
import 'package:uwearis/features/pages/settings/style_taste_page.dart';
import 'package:uwearis/features/widgets/common/profile_avatar.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/mock_http.dart';
import '../../helpers/widget_harness.dart';

class _FakeOutfits extends OutfitsNotifier {
  _FakeOutfits(this._items);
  final List<Outfit> _items;

  @override
  Future<List<Outfit>> build() async => _items;
}

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

  testWidgets('tapping Log out asks for confirmation instead of logging out '
      'immediately', (tester) async {
    await runWithProfile(() async {
      useTallSurface(tester);
      await pumpApp(tester, const SettingsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  testWidgets('Closing the logout confirmation keeps the user on Settings', (
    tester,
  ) async {
    await runWithProfile(() async {
      useTallSurface(tester);
      await pumpApp(tester, const SettingsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppDialog.closeButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  testWidgets(
    'confirming Log out clears any cached closet-analysis results — this '
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

        await tester.tap(find.text('Log out'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log out').last);
        await tester.pump();
        // LoginPage's Google-button network image fails in flutter_test and
        // its fallback overflows; unrelated to this test, so drain them.
        while (tester.takeException() != null) {}
      });

      expect(await GarmentService().cachedClosetAnalysis(4242), isNull);
    },
  );

  group('My Outfit Profile entry', () {
    testWidgets('one entry replaces My Virtual Model and Temperature '
        'Preference', (tester) async {
      await runWithProfile(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();

        expect(find.text('My Outfit Profile'), findsOneWidget);
        expect(find.text('My Virtual Model'), findsNothing);
        expect(find.text('Temperature Preference'), findsNothing);
        expect(find.text('Lifestyle'), findsNothing);
        expect(find.text('Personal Details'), findsOneWidget);
        expect(find.text('Style Taste'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
      });
    });

    testWidgets('tapping it opens My Outfit Profile, and back returns to '
        'Settings', (tester) async {
      await runWithProfile(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();

        await tester.tap(find.text('My Outfit Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(MyOutfitProfilePage), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(MyOutfitProfilePage), findsNothing);
        expect(find.byType(SettingsPage), findsOneWidget);
      });
    });
  });

  group('Style Taste', () {
    Future<void> pumpWithOutfits(WidgetTester tester, List<Outfit> outfits) {
      return runWithProfile(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          const SettingsPage(),
          overrides: [
            outfitsProvider.overrideWith(() => _FakeOutfits(outfits)),
          ],
        );
        await tester.pumpAndSettle();
      });
    }

    Finder dimmedStyleTaste() => find.ancestor(
      of: find.text('Style Taste'),
      matching: find.byType(Opacity),
    );

    testWidgets('is locked when the user has no outfits', (tester) async {
      await pumpWithOutfits(tester, const []);

      expect(dimmedStyleTaste(), findsOneWidget);
      await tester.tap(find.text('Style Taste'));
      await tester.pumpAndSettle();
      expect(find.byType(StyleTastePage), findsNothing);
    });

    testWidgets('is enabled once the user has an outfit', (tester) async {
      await pumpWithOutfits(tester, [
        Outfit(id: 1, imageUrl: '', garmentIds: const [1]),
      ]);

      expect(dimmedStyleTaste(), findsNothing);
    });
  });

  group('Plus badge', () {
    Future<void> pumpWithExpiry(WidgetTester tester, String? expiresAt) {
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
              'subscription_expires_at': ?expiresAt,
            }),
          ),
        ),
      );
    }

    ProfileAvatar avatar(WidgetTester tester) =>
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));

    testWidgets(
      'an active subscription shows Uwearis Plus and an accent ring',
      (tester) async {
        await pumpWithExpiry(
          tester,
          DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        );
        expect(find.text('Uwearis Plus'), findsOneWidget);
        expect(avatar(tester).ringColor, AppColors.accent);
      },
    );

    for (final (label, expiresAt) in [
      ('never subscribed', null),
      ('expired', '2020-01-01T00:00:00+08:00'),
    ]) {
      testWidgets('$label: no badge, no ring', (tester) async {
        await pumpWithExpiry(tester, expiresAt);
        expect(find.text('Uwearis Plus'), findsNothing);
        expect(avatar(tester).ringColor, isNull);
      });
    }
  });

  group('Help & Legal', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'Uwearis',
        packageName: 'com.uwearis.app',
        version: '1.0.0',
        buildNumber: '16',
        buildSignature: '',
      );
    });

    testWidgets('the card shows the app version and opens the three links', (
      tester,
    ) async {
      await runWithProfile(() async {
        useTallSurface(tester);
        await pumpApp(tester, const SettingsPage());
        await tester.pumpAndSettle();

        expect(find.text('Help & Legal'), findsOneWidget);
        expect(find.text('Version 1.0.0 (16)'), findsOneWidget);

        await tester.tap(find.text('Help & Legal'));
        await tester.pumpAndSettle();

        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Terms of Service'), findsOneWidget);
        expect(find.text('Contact Support'), findsOneWidget);
      });
    });
  });

  group('withdraw AI consent', () {
    setUp(() => UserAcknowledgement.debugGrantedOverride = null);
    tearDown(() => UserAcknowledgement.debugGrantedOverride = true);

    Future<void> openHelpAndLegal(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(tester, const SettingsPage());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help & Legal'));
      await tester.pumpAndSettle();
    }

    testWidgets('hidden until consent was given', (tester) async {
      await runWithProfile(() async {
        await openHelpAndLegal(tester);
        expect(find.text('Contact Support'), findsOneWidget);
        expect(find.text('Withdraw AI Consent'), findsNothing);
      });
    });

    testWidgets('confirming clears the stored consent', (tester) async {
      await runWithProfile(() async {
        await UserAcknowledgement.aiConsent.grant();
        await openHelpAndLegal(tester);

        await tester.tap(find.text('Withdraw AI Consent'));
        await tester.pumpAndSettle();
        expect(find.text('Withdraw AI Consent?'), findsOneWidget);

        await tester.tap(find.text('Withdraw'));
        await tester.pumpAndSettle();
        expect(await UserAcknowledgement.aiConsent.isGranted(), isFalse);
        expect(find.text('AI consent withdrawn'), findsOneWidget);
      });
    });

    testWidgets('cancelling keeps it', (tester) async {
      await runWithProfile(() async {
        await UserAcknowledgement.aiConsent.grant();
        await openHelpAndLegal(tester);

        await tester.tap(find.text('Withdraw AI Consent'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AppDialog.closeButtonKey));
        await tester.pumpAndSettle();
        expect(await UserAcknowledgement.aiConsent.isGranted(), isTrue);
      });
    });
  });

  testWidgets('declining AI consent keeps Style Taste closed', (tester) async {
    UserAcknowledgement.debugGrantedOverride = false;
    addTearDown(() => UserAcknowledgement.debugGrantedOverride = true);
    await runWithProfile(() async {
      useTallSurface(tester);
      await pumpApp(tester, const SettingsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Style Taste'));
      await tester.pumpAndSettle();
      expect(find.text('How AI Features Use Your Data'), findsOneWidget);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
      expect(find.byType(StyleTastePage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });
}
