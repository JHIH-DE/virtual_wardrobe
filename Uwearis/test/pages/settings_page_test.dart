import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/style_taste_page.dart';
import 'package:uwearis/features/widgets/common/profile_avatar.dart';
import 'package:uwearis/features/pages/login_page.dart';
import 'package:uwearis/features/pages/my_outfit_profile_page.dart';
import 'package:uwearis/features/pages/settings_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

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

  testWidgets('Cancel on the logout confirmation keeps the user on Settings', (
    tester,
  ) async {
    await runWithProfile(() async {
      useTallSurface(tester);
      await pumpApp(tester, const SettingsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
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
        expect(
          find.text('Virtual model & temperature comfort'),
          findsOneWidget,
        );
        expect(find.text('My Virtual Model'), findsNothing);
        expect(find.text('Temperature Preference'), findsNothing);
        expect(find.text('Lifestyle'), findsNothing);
        expect(find.text('Account'), findsOneWidget);
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

    testWidgets('is locked with a reason when the user has no outfits', (
      tester,
    ) async {
      await pumpWithOutfits(tester, const []);

      expect(find.text('Create an outfit to unlock'), findsOneWidget);
      await tester.tap(find.text('Style Taste'));
      await tester.pumpAndSettle();
      expect(find.byType(StyleTastePage), findsNothing);
    });

    testWidgets('is enabled once the user has an outfit', (tester) async {
      await pumpWithOutfits(tester, [
        Outfit(id: 1, imageUrl: '', garmentIds: const [1]),
      ]);

      expect(find.text('Your outfit preferences'), findsOneWidget);
      expect(find.text('Create an outfit to unlock'), findsNothing);
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

    for (final (tier, color) in [
      ('tier_1', AppColors.tierGold),
      ('tier_2', AppColors.tierSilver),
      (null, AppColors.tierBronze),
    ]) {
      testWidgets('the avatar ring matches the ${tier ?? 'default'} badge', (
        tester,
      ) async {
        await pumpWithTier(tester, tier);
        final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
        expect(avatar.ringColor, color);
      });
    }
  });
}
