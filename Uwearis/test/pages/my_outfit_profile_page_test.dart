import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/utils/base_model_generation_mixin.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/my_outfit_profile_page.dart';
import 'package:uwearis/features/pages/reference_photos_page.dart';
import 'package:uwearis/features/widgets/common/app_tool_bar.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/cards/generated_image_card.dart';
import 'package:uwearis/features/widgets/common/fields/number_stepper.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

final _l10n = AppLocalizationsEn();

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier({ProfileData? data}) : data = data ?? complete;

  /// Both reference photos, no base model yet.
  static const complete = ProfileData(
    profile: UserProfile(name: 'Test User'),
    bodyRefUrl: 'https://example.com/body.jpg',
    faceRefUrl: 'https://example.com/face.jpg',
  );

  static const empty = ProfileData(profile: UserProfile(name: 'Test User'));

  final ProfileData data;

  @override
  Future<ProfileData> build() async => data;
}

class _FailingProfileNotifier extends ProfileNotifier {
  @override
  Future<ProfileData> build() async => throw Exception('boom');
}

final _generatePill = find.ancestor(
  of: find.text(_l10n.virtualModelGenerateAction),
  matching: find.byType(AccentPillButton),
);

final _editPhotosPill = find.byKey(const ValueKey('editPhotosAction'));

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  ProfileNotifier? notifier,
  GenerateBaseModel? generate,
}) {
  return pumpApp(
    tester,
    const MyOutfitProfilePage(),
    overrides: [
      profileProvider.overrideWith(() => notifier ?? _FakeProfileNotifier()),
      generateBaseModelProvider.overrideWithValue(
        generate ?? () async => fail('generate must not be called'),
      ),
    ],
    retry: (_, _) => null,
  );
}

/// Records PATCH /users/me bodies; [patchStatus] other than 200 fails them.
http.Client _profileClient(
  List<Map<String, dynamic>> patches, {
  int patchStatus = 200,
}) => MockClient((request) async {
  if (request.method == 'PATCH') {
    patches.add(jsonDecode(request.body) as Map<String, dynamic>);
    return patchStatus == 200
        ? jsonResponse(envelope({'name': 'Test User'}))
        : jsonResponse(envelope(null), status: patchStatus);
  }
  return jsonResponse(envelope({'name': 'Test User'}));
});

void main() {
  setUp(() {
    setUpFakeAuth();
    SharedPreferences.setMockInitialValues({});
  });

  group('virtual model', () {
    testWidgets(
      'no photos and no model: Generate is disabled with the body-photo '
      'hint, Edit stays available, and temperature still works',
      (tester) async {
        _useTallSurface(tester);
        final patches = <Map<String, dynamic>>[];
        await http.runWithClient(() async {
          await _pumpPage(
            tester,
            notifier: _FakeProfileNotifier(data: _FakeProfileNotifier.empty),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(_l10n.virtualModelGenerateRequiresBodyRefHint),
            findsOneWidget,
          );
          expect(
            tester.widget<AccentPillButton>(_generatePill).enabled,
            isFalse,
          );
          expect(
            tester.widget<AccentPillButton>(_editPhotosPill).enabled,
            isTrue,
          );

          await tester.tap(find.byIcon(Icons.add_circle_outline));
          await tester.pumpAndSettle();
          expect(find.text('+1°C'), findsOneWidget);
        }, () => _profileClient(patches));
        expect(patches, [
          {'temperature_offset_c': 1},
        ]);
      },
    );

    testWidgets('Edit opens the reference photos page, and a photo '
        'committed there is what this page shows on return', (tester) async {
      _useTallSurface(tester);
      await _pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(_editPhotosPill);
      await tester.pumpAndSettle();
      expect(find.byType(ReferencePhotosPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppToolBar),
          matching: find.text(_l10n.edit),
        ),
        findsOneWidget,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReferencePhotosPage)),
      );
      container
          .read(profileProvider.notifier)
          .setBodyRefUrl('https://example.com/body-new.jpg');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(MyOutfitProfilePage), findsOneWidget);
      expect(find.byType(ReferencePhotosPage), findsNothing);
      expect(
        container.read(profileProvider).value!.bodyRefUrl,
        'https://example.com/body-new.jpg',
      );
      expect(tester.widget<AccentPillButton>(_generatePill).enabled, isTrue);
    });

    testWidgets('a failed profile load shows a retryable error in the model '
        'section only; temperature stays usable', (tester) async {
      _useTallSurface(tester);
      await _pumpPage(tester, notifier: _FailingProfileNotifier());
      await tester.pumpAndSettle();

      expect(find.text(_l10n.failedToLoad), findsOneWidget);
      expect(_editPhotosPill, findsNothing);
      final stepper = tester.widget<NumberStepper>(find.byType(NumberStepper));
      expect(stepper.onIncrement, isNotNull);
      expect(stepper.onDecrement, isNotNull);
    });

    testWidgets(
      'Generate confirms first, then calls generateBaseModel, commits its '
      'URL with no success dialog — without touching the temperature',
      (tester) async {
        _useTallSurface(tester);
        var calls = 0;
        final patches = <Map<String, dynamic>>[];
        await http.runWithClient(() async {
          await _pumpPage(
            tester,
            // '' not a real URL: a real fetch needs a sqflite factory the
            // harness lacks.
            generate: () async {
              calls++;
              return '';
            },
          );
          await tester.pumpAndSettle();

          await tester.tap(_generatePill);
          await tester.pumpAndSettle();
          expect(
            find.text(_l10n.virtualModelGenerateConfirmTitle),
            findsOneWidget,
          );
          expect(calls, 0);

          await tester.tap(find.text(_l10n.virtualModelGenerateAction).last);
          await tester.pumpAndSettle();

          expect(calls, 1);
          // Success is silent: no "Done" dialog, the new image is shown.
          expect(find.byType(Dialog), findsNothing);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MyOutfitProfilePage)),
          );
          expect(container.read(profileProvider).value!.baseModelUrl, '');
        }, () => _profileClient(patches));
        expect(patches, isEmpty);
      },
    );

    testWidgets('a failed generation shows an error dialog', (tester) async {
      _useTallSurface(tester);
      await _pumpPage(tester, generate: () async => throw Exception('boom'));
      await tester.pumpAndSettle();

      await tester.tap(_generatePill);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.virtualModelGenerateAction).last);
      await tester.pumpAndSettle();

      expect(find.text(_l10n.virtualModelGenerateFailed), findsOneWidget);
    });

    testWidgets('each successful generation bumps the image cache key, so a '
        "regenerate can't keep showing the stale cached bytes", (tester) async {
      _useTallSurface(tester);
      var calls = 0;
      await _pumpPage(
        tester,
        generate: () async {
          calls++;
          return '';
        },
      );
      await tester.pumpAndSettle();

      String cacheKeyOf() => tester
          .widget<GeneratedImageCard>(find.byType(GeneratedImageCard))
          .cacheKey!;
      final before = cacheKeyOf();

      await tester.tap(_generatePill);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.virtualModelGenerateAction).last);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(cacheKeyOf(), isNot(before));
    });

    testWidgets(
      'an expired base model URL re-signs through getBaseModel and syncs the '
      'fresh URL back with compare-and-set',
      (tester) async {
        _useTallSurface(tester);
        const original = 'https://example.com/base-model.jpg';
        var refreshCalls = 0;
        await pumpApp(
          tester,
          const MyOutfitProfilePage(),
          overrides: [
            profileProvider.overrideWith(
              () => _FakeProfileNotifier(
                data: _FakeProfileNotifier.complete.copyWith(
                  baseModelUrl: original,
                ),
              ),
            ),
            fetchFreshBaseModelUrlProvider.overrideWithValue(() async {
              refreshCalls++;
              return 'https://example.com/base-model-fresh.jpg';
            }),
          ],
        );
        await tester.pump();

        GeneratedImageCard card() =>
            tester.widget<GeneratedImageCard>(find.byType(GeneratedImageCard));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MyOutfitProfilePage)),
        );

        final fresh = await card().onRefreshUrl!();
        expect(refreshCalls, 1);

        card().onUrlRefreshed!(original, fresh!);
        await tester.pump();
        expect(container.read(profileProvider).value!.baseModelUrl, fresh);
        expect(card().imageUrl, fresh);

        // A late refresh of the old URL must not revert the newer one.
        card().onUrlRefreshed!(original, 'https://example.com/stale.jpg');
        await tester.pump();
        expect(container.read(profileProvider).value!.baseModelUrl, fresh);
      },
    );
  });

  group('temperature adjustment', () {
    testWidgets('shows the locally cached offset', (tester) async {
      SharedPreferences.setMockInitialValues({'temperature_offset': -2});
      _useTallSurface(tester);
      await _pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.text(_l10n.temperatureAdjustmentTitle), findsOneWidget);
      expect(find.text('-2°C'), findsOneWidget);
      expect(find.text(_l10n.temperatureAdjustmentWarmer), findsOneWidget);
      expect(find.text(_l10n.temperatureAdjustmentLighter), findsOneWidget);
    });

    testWidgets('stepping PATCHes only temperature_offset_c and caches the '
        'saved value for the next visit', (tester) async {
      _useTallSurface(tester);
      final patches = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await _pumpPage(tester);
        await tester.pumpAndSettle();
        expect(find.text('0°C'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        expect(find.text('+2°C'), findsOneWidget);
      }, () => _profileClient(patches));

      expect(patches, isNotEmpty);
      for (final body in patches) {
        expect(body.keys, ['temperature_offset_c']);
      }
      expect(patches.last, {'temperature_offset_c': 2});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('temperature_offset'), 2);

      // Re-entering reads the saved value back.
      await tester.pumpWidget(const SizedBox());
      await _pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.text('+2°C'), findsOneWidget);
    });

    testWidgets('a failed save offers Retry and leaves the cache untouched, '
        'and leaving asks before discarding it', (tester) async {
      _useTallSurface(tester);
      final patches = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await pumpApp(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyOutfitProfilePage(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
          ],
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.retry), findsOneWidget);
        await tester.tap(find.text(_l10n.cancel));
        await tester.pumpAndSettle();
        expect(find.text('+1°C'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text(_l10n.unsavedChangesTitle), findsOneWidget);
        await tester.tap(find.text(_l10n.dontSave));
        await tester.pumpAndSettle();
        expect(find.byType(MyOutfitProfilePage), findsNothing);
      }, () => _profileClient(patches, patchStatus: 500));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('temperature_offset'), isNull);
    });

    testWidgets('+ is disabled at the +5°C upper bound', (tester) async {
      SharedPreferences.setMockInitialValues({'temperature_offset': 5});
      _useTallSurface(tester);
      await _pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.text('+5°C'), findsOneWidget);
      final stepper = tester.widget<NumberStepper>(find.byType(NumberStepper));
      expect(stepper.onIncrement, isNull);
      expect(stepper.onDecrement, isNotNull);
    });
  });

  group('layout', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      for (final withModel in [false, true]) {
        testWidgets('${describeCase(c)} · ${withModel ? 'model' : 'no model'}: '
            'nothing overflows or truncates', (tester) async {
          applyLayoutCase(tester, c, height: 2400);
          await pumpApp(
            tester,
            const MyOutfitProfilePage(),
            overrides: [
              profileProvider.overrideWith(
                () => _FakeProfileNotifier(
                  data: withModel
                      ? _FakeProfileNotifier.complete.copyWith(
                          baseModelUrl: 'https://example.com/model.jpg',
                        )
                      : _FakeProfileNotifier.empty,
                ),
              ),
            ],
          );
          await tester.pump();
          await tester.pump();

          final l10n = AppLocalizations.of(
            tester.element(find.byType(MyOutfitProfilePage)),
          );
          final page = find.byType(MyOutfitProfilePage);
          for (final text in [
            l10n.virtualModelSectionTitle,
            l10n.edit,
            l10n.virtualModelSectionSubtitle,
            l10n.temperatureAdjustmentTitle,
            l10n.temperatureAdjustmentDescription,
            l10n.temperatureAdjustmentWarmer,
            l10n.temperatureAdjustmentLighter,
          ]) {
            final f = find.text(text);
            expect(f, findsOneWidget, reason: text);
            expectWithin(tester, f, page);
          }
          for (final text in [
            l10n.virtualModelSectionSubtitle,
            l10n.temperatureAdjustmentDescription,
            l10n.temperatureAdjustmentWarmer,
            l10n.temperatureAdjustmentLighter,
          ]) {
            expectNoBrokenWords(tester, find.text(text));
          }
          // Warmer belongs to −, Lighter to +, beside or under each.
          final minus = tester.getCenter(
            find.byIcon(Icons.remove_circle_outline),
          );
          final plus = tester.getCenter(find.byIcon(Icons.add_circle_outline));
          final warmer = tester.getCenter(
            find.text(l10n.temperatureAdjustmentWarmer),
          );
          final lighter = tester.getCenter(
            find.text(l10n.temperatureAdjustmentLighter),
          );
          expect(warmer.dx, lessThan(plus.dx));
          expect(lighter.dx, greaterThan(minus.dx));
          expect(warmer.dx, lessThan(lighter.dx));
          if (c.width == 390 && c.scale == 1.0) {
            expect(warmer.dx, lessThan(minus.dx));
            expect(lighter.dx, greaterThan(plus.dx));
            expect(warmer.dy, closeTo(minus.dy, 2));
          }
          expect(isTruncated(tester, find.text(l10n.edit)), false);
          // Edit sits in the preview's bottom-right corner, and in
          // the empty state never overlaps the Generate content.
          final preview = find.byType(GeneratedImageCard);
          final card = tester.getRect(preview);
          final edit = tester.getRect(_editPhotosPill);
          expectWithin(tester, _editPhotosPill, preview);
          expect(card.right - edit.right, lessThanOrEqualTo(16));
          expect(card.bottom - edit.bottom, lessThanOrEqualTo(8));
          if (withModel) {
            expect(card.height, closeTo(card.width * 5 / 4, 1));
          } else {
            final generate = find.ancestor(
              of: find.text(l10n.virtualModelGenerateAction),
              matching: find.byType(AccentPillButton),
            );
            expect(tester.getRect(generate).overlaps(edit), isFalse);
          }
        });
      }
    }
  });
}
