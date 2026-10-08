import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/account_page.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

final _l10n = AppLocalizationsEn();

/// A fully filled-in profile (name/gender/birthday/location + height/weight
/// in metric) — mirrors my_virtual_model_page_test.dart's own fake.
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier({ProfileData? data}) : data = data ?? _complete;

  static final _complete = ProfileData(
    profile: UserProfile(
      name: 'Test User',
      gender: 'Male',
      location: 'Taipei',
      birthDate: DateTime(1996, 3, 11),
      height: 178,
      weight: 70,
      unitSystem: 'metric',
    ),
  );

  final ProfileData data;

  @override
  Future<ProfileData> build() async => data;
}

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    "the Body Measurements card shows the profile's height/weight in metric "
    'by default',
    (tester) async {
      await pumpApp(
        tester,
        const AccountPage(),
        overrides: [profileProvider.overrideWith(() => _FakeProfileNotifier())],
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(_l10n.bodyMeasurementsLabel.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('178'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
    },
  );

  /// Records every PATCH body; [fail] makes responses 500s.
  List<Map<String, dynamic>> patches = [];
  var fail = false;
  MockClient backend() => MockClient((request) async {
    patches.add(jsonDecode(request.body) as Map<String, dynamic>);
    if (fail) return jsonResponse({'success': false}, status: 500);
    return jsonResponse(envelope({'name': 'Test User', 'weight': 72}));
  });

  setUp(() {
    patches = [];
    fail = false;
  });

  Future<void> pumpAccount(
    WidgetTester tester, {
    bool completingOnboarding = false,
  }) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AccountPage(completingOnboarding: completingOnboarding),
      overrides: [profileProvider.overrideWith(() => _FakeProfileNotifier())],
    );
    await tester.pump();
    await tester.pump();
  }

  /// Pushes AccountPage over a placeholder home so popping is observable.
  Future<void> pushAccount(WidgetTester tester) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountPage()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [profileProvider.overrideWith(() => _FakeProfileNotifier())],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final backButton = find.ancestor(
    of: find.image(const AssetImage('assets/images/page_arrow_left.png')),
    matching: find.byType(IconButton),
  );

  testWidgets(
    'from Settings there is no Save button; typing a weight auto-saves '
    'after a pause, sending the untouched profile fields alongside',
    (tester) async {
      await http.runWithClient(() async {
        await pumpAccount(tester);
        expect(
          find.byKey(const ValueKey('bottomActionButton-visible')),
          findsNothing,
        );

        await tester.enterText(find.text('70'), '72');
        await tester.pump(const Duration(milliseconds: 500));
        expect(patches, isEmpty);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(patches, hasLength(1));
        final body = patches.single;
        expect(body['weight'], 72);
        expect(body['height'], 178);
        expect(body['unit_system'], 'metric');
        expect(body['name'], 'Test User');
        expect(body['gender'], 'Male');
        expect(body['location'], 'Taipei');
        expect(
          find.byKey(const ValueKey('bottomActionButton-visible')),
          findsNothing,
        );
      }, backend);
    },
  );

  testWidgets('leaving a text field saves right away instead of waiting out '
      'the pause', (tester) async {
    await http.runWithClient(() async {
      await pumpAccount(tester);

      await tester.enterText(find.text('Test User'), 'New Name');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();

      expect(patches.single['name'], 'New Name');
      // The debounce that was pending doesn't fire a second save.
      await tester.pump(const Duration(seconds: 1));
      expect(patches, hasLength(1));
    }, backend);
  });

  testWidgets('a cleared name is left out of the save rather than sent '
      'empty', (tester) async {
    await http.runWithClient(() async {
      await pumpAccount(tester);

      await tester.enterText(find.text('Test User'), '');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(patches.single.containsKey('name'), isFalse);
    }, backend);
  });

  testWidgets(
    'switching to Imperial converts the displayed height/weight and saves '
    'the new unit immediately',
    (tester) async {
      await http.runWithClient(() async {
        await pumpAccount(tester);

        await tester.tap(find.text(_l10n.unitImperialLabel));
        await tester.pump();
        await tester.pump();

        // 178cm/70kg converted to ft/in/lb.
        expect(find.text('5'), findsOneWidget); // feet
        expect(find.text('10'), findsOneWidget); // inches
        expect(find.text('154'), findsOneWidget); // lb
        expect(patches.single['unit_system'], 'imperial');
        // Still stored canonically in cm/kg.
        expect(patches.single['height'], 178);
      }, backend);
    },
  );

  testWidgets('back while a typed change is still waiting saves it first, '
      'then pops', (tester) async {
    await http.runWithClient(() async {
      await pushAccount(tester);

      await tester.enterText(find.text('70'), '72');
      await tester.pump();
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(patches.single['weight'], 72);
      expect(find.byType(AccountPage), findsNothing);
    }, backend);
  });

  testWidgets('a failed auto-save offers Retry', (tester) async {
    fail = true;
    await http.runWithClient(() async {
      await pumpAccount(tester);

      await tester.tap(find.text(_l10n.unitImperialLabel));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.profileSaveFailed), findsOneWidget);

      fail = false;
      await tester.tap(find.text(_l10n.retry));
      await tester.pumpAndSettle();
      expect(patches, hasLength(2));
      expect(find.text(_l10n.profileSaveFailed), findsNothing);
    }, backend);
  });

  testWidgets('onboarding keeps Continue and does not auto-save edits', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpAccount(tester, completingOnboarding: true);

      expect(
        find.byKey(const ValueKey('bottomActionButton-visible')),
        findsOneWidget,
      );
      expect(find.text(_l10n.continueLabel), findsOneWidget);

      await tester.enterText(find.text('70'), '72');
      await tester.tap(find.text(_l10n.unitImperialLabel));
      await tester.pump(const Duration(seconds: 1));
      expect(patches, isEmpty);
    }, backend);
  });

  testWidgets('picking a gender from the sheet saves it right away', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpAccount(tester);

      await tester.tap(find.text(_l10n.genderMale));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.genderFemale));
      await tester.pumpAndSettle();

      expect(patches.single['gender'], 'Female');
      expect(find.text(_l10n.genderFemale), findsOneWidget);
    }, backend);
  });
}
