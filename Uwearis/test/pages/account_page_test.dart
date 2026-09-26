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

  testWidgets(
    'editing weight alone enables Save, and Save PATCHes height/weight/'
    'unit_system alongside the untouched profile fields',
    (tester) async {
      await tester.runAsync(() async {
        useTallSurface(tester);
        late http.Request captured;
        await http.runWithClient(() async {
          await pumpApp(
            tester,
            const AccountPage(),
            overrides: [
              profileProvider.overrideWith(() => _FakeProfileNotifier()),
            ],
          );
          await tester.pump();
          await tester.pump();

          // Nothing edited yet — Save stays hidden.
          expect(
            find.byKey(const ValueKey('bottomActionButton-visible')),
            findsNothing,
          );

          await tester.enterText(find.text('70'), '72');
          await tester.pump();

          expect(
            find.byKey(const ValueKey('bottomActionButton-visible')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(const ValueKey('bottomActionButton-visible')),
          );
          await tester.pump();
          // Navigator.pop on the test harness's single-route MaterialApp has
          // nothing to actually pop to — drain that, it's unrelated to what
          // this test checks (the outgoing PATCH body).
          while (tester.takeException() != null) {}
        }, () => MockClient((request) async {
          captured = request;
          return jsonResponse(
            envelope({
              'name': 'Test User',
              'gender': 'Male',
              'location': 'Taipei',
              'height': 178,
              'weight': 72,
              'unit_system': 'metric',
            }),
          );
        }));

        expect(captured.method, 'PATCH');
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['weight'], 72);
        expect(body['height'], 178);
        expect(body['unit_system'], 'metric');
        // The fields this test didn't touch are still sent unchanged.
        expect(body['name'], 'Test User');
        expect(body['gender'], 'Male');
        expect(body['location'], 'Taipei');
      });
    },
  );

  testWidgets(
    'switching to Imperial converts the displayed height/weight and marks '
    'the page modified even with no field directly edited',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const AccountPage(),
        overrides: [profileProvider.overrideWith(() => _FakeProfileNotifier())],
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('bottomActionButton-visible')),
        findsNothing,
      );

      await tester.tap(find.text(_l10n.unitImperialLabel));
      await tester.pump();

      // 178cm/70kg converted to ft/in/lb.
      expect(find.text('5'), findsOneWidget); // feet
      expect(find.text('10'), findsOneWidget); // inches
      expect(find.text('154'), findsOneWidget); // lb
      expect(
        find.byKey(const ValueKey('bottomActionButton-visible')),
        findsOneWidget,
      );
    },
  );
}
