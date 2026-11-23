import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/style_profile_provider.dart';
import 'package:uwearis/core/providers/style_taste_provider.dart';
import 'package:uwearis/core/providers/temperature_coverage_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/style_profile.dart';
import 'package:uwearis/data/style_taste.dart';
import 'package:uwearis/data/temperature_coverage.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/outfit/outfit_insights_sheet.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/fake_auth.dart';
import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';
import '../helpers/seeded_notifiers.dart';

final _l10n = AppLocalizationsEn();

/// Throws after a short delay: the page's AuthExpired listeners attach
/// post-frame, and an immediate throw would race ahead of them.
class _FailingStyleTasteNotifier extends StyleTasteProfileNotifier {
  @override
  Future<StyleTasteProfile> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw AuthExpiredException();
  }
}

class _SeededStyleTasteNotifier extends StyleTasteProfileNotifier {
  @override
  Future<StyleTasteProfile> build() async => const StyleTasteProfile(
    status: 'ready',
    summary: '',
    preferences: [
      StyleTastePreference(
        dimension: StyleTasteDimension.styleBalance,
        score: 0.8,
        confidence: 1,
        description: 'You mix styles freely.',
      ),
      StyleTastePreference(
        dimension: StyleTasteDimension.colorPairing,
        score: 0.3,
        confidence: 1,
      ),
      StyleTastePreference(
        dimension: StyleTasteDimension.fitPreference,
        score: 0.5,
        confidence: 1,
      ),
      StyleTastePreference(
        dimension: StyleTasteDimension.layering,
        score: 0.6,
        confidence: 1,
      ),
      StyleTastePreference(
        dimension: StyleTasteDimension.accessories,
        score: 0.2,
        confidence: 1,
      ),
    ],
  );
}

const _coverage = TemperatureCoverage(
  temperatureOffsetC: 0,
  usableOutfitCount: 7,
  enoughCount: 3,
  bands: [
    TemperatureBand(
      key: 'freezing',
      label: 'Freezing',
      minC: null,
      maxC: 0,
      outfitCount: 5,
      status: TemperatureCoverageStatus.enough,
    ),
    TemperatureBand(
      key: 'cool',
      label: 'Cool',
      minC: 15,
      maxC: 20,
      outfitCount: 0,
      status: TemperatureCoverageStatus.none,
    ),
    TemperatureBand(
      key: 'hot',
      label: 'Hot',
      minC: 29,
      maxC: null,
      outfitCount: 2,
      status: TemperatureCoverageStatus.few,
    ),
  ],
);

class _EmptyStyleProfileNotifier extends StyleProfileNotifier {
  @override
  Future<List<StyleProfileItem>> build() async => const [];
}

void main() {
  setUp(() {
    setUpFakeAuth();
    // clearSignedInSession() touches SharedPreferences, which never
    // resolves in a test binding without this.
    SharedPreferences.setMockInitialValues({});
  });

  // ErrorStateWidget renders nothing for AuthExpiredException, so the sheet
  // needs its own listener to prompt re-login.
  testWidgets('an AuthExpiredException on styleTasteProfileProvider shows the '
      'session-expired dialog instead of going blank', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: OutfitInsightsSheetContent()),
      overrides: [
        styleTasteProfileProvider.overrideWith(_FailingStyleTasteNotifier.new),
        styleProfileProvider.overrideWith(_EmptyStyleProfileNotifier.new),
        outfitsProvider.overrideWith(() => SeededOutfitsNotifier(const [])),
        temperatureCoverageProvider.overrideWith((ref) async => _coverage),
      ],
    );
    await tester.pump();
    // Past the override's delay plus AuthExpiredHandler's async chain.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.sessionExpiredTitle), findsOneWidget);
  });

  group('tabs', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpApp(
        tester,
        const Scaffold(body: OutfitInsightsSheetContent()),
        overrides: [
          styleTasteProfileProvider.overrideWith(_SeededStyleTasteNotifier.new),
          styleProfileProvider.overrideWith(_EmptyStyleProfileNotifier.new),
          outfitsProvider.overrideWith(() => SeededOutfitsNotifier(const [])),
          temperatureCoverageProvider.overrideWith((ref) async => _coverage),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens on Style; Temperature is not shown until selected', (
      tester,
    ) async {
      await pumpSheet(tester);

      expect(find.text('Style Profile'), findsOneWidget);
      expect(find.text(_l10n.styleProfileCardTitle), findsOneWidget);
      expect(find.text(_l10n.temperatureCoverageCardTitle), findsNothing);

      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.temperatureCoverageCardTitle), findsOneWidget);
      expect(find.text('Style Profile'), findsNothing);
    });

    testWidgets('Temperature lists each band with only its count — no '
        'header, add link or + icon', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();

      for (final name in ['Freezing', 'Cool', 'Hot']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Below 0°C'), findsOneWidget);
      expect(find.text('15–20°C'), findsOneWidget);
      expect(find.text('29°C and above'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Outfits'), findsNothing);
      expect(find.textContaining('Add'), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('each tab keeps its scroll position across switches', (
      tester,
    ) async {
      await pumpSheet(tester, size: const Size(390, 500));
      final styleList = find.byType(Scrollable).first;
      await tester.drag(styleList, const Offset(0, -200));
      await tester.pumpAndSettle();
      final before = tester.state<ScrollableState>(styleList).position.pixels;
      expect(before, greaterThan(0));

      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        before,
      );
    });

    testWidgets('Style Insights live in the Style Profile info dialog, not '
        'on the card', (tester) async {
      await pumpSheet(tester, size: const Size(390, 2000));
      expect(find.text('You mix styles freely.'), findsNothing);
      expect(find.text(_l10n.styleTasteDetailsLabel), findsNothing);

      await tester.tap(find.byTooltip(_l10n.moreInfo));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.styleTasteDetailsLabel), findsOneWidget);
      expect(find.text('You mix styles freely.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Color Pairing'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('both tab lists end clear of the bottom safe area', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      await pumpSheet(tester);
      final style = tester.widget<ListView>(find.byType(ListView).first);
      expect((style.padding! as EdgeInsets).bottom, 34);

      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();
      final temperature = tester.widget<ListView>(find.byType(ListView).last);
      expect((temperature.padding! as EdgeInsets).bottom, 34);
    });

    testWidgets('the Temperature card has no info button', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(_l10n.moreInfo), findsNothing);
    });
  });

  group('enlarged text', () {
    setUpAll(loadAppFont);
    for (final c in layoutCases) {
      testWidgets('both tabs lay out at ${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c);
        await pumpApp(
          tester,
          const Scaffold(body: OutfitInsightsSheetContent()),
          overrides: [
            styleTasteProfileProvider.overrideWith(
              _SeededStyleTasteNotifier.new,
            ),
            styleProfileProvider.overrideWith(_EmptyStyleProfileNotifier.new),
            outfitsProvider.overrideWith(() => SeededOutfitsNotifier(const [])),
            temperatureCoverageProvider.overrideWith((ref) async => _coverage),
          ],
        );
        await tester.pumpAndSettle();
        final isEn = c.locale.languageCode == 'en';
        final styleTab = isEn ? 'Style' : '風格';
        final tempTab = isEn ? 'Temperature' : '溫度';
        for (final tab in [styleTab, tempTab]) {
          expect(isTruncated(tester, find.text(tab)), isFalse);
          expectNoBrokenWords(tester, find.text(tab));
        }
        expect(tester.takeException(), isNull);

        // Radar axis titles stay whole, beside the plot or in its list.
        for (final title
            in isEn
                ? ['Style Balance', 'Color Pairing', 'Fit Preference']
                : ['風格平衡', '色彩搭配', '版型偏好']) {
          final finder = find.text(title);
          expect(finder, findsOneWidget);
          expect(isTruncated(tester, finder), isFalse);
          expectNoBrokenWords(tester, finder);
        }

        await tester.tap(find.byType(CircleIconButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final title = find.text(isEn ? 'Fit Preference' : '版型偏好').last;
        expect(isTruncated(tester, title), isFalse);
        expectNoBrokenWords(tester, title);
        await tester.tap(find.byKey(AppDialog.dismissButtonKey));
        await tester.pumpAndSettle();

        await tester.tap(find.text(tempTab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final range = find.text(isEn ? '15–20°C' : '15~20°C');
        expect(renderedLineCount(tester, range), 1);
        expect(isTruncated(tester, find.text('Cool')), isFalse);
      });
    }
  });
}
