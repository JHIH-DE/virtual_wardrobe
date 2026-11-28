import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/core/providers/magazine_provider.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis/features/pages/common/editorial_story_preview.dart';
import 'package:uwearis/features/pages/explore/editorial_story_page.dart';
import 'package:uwearis/features/widgets/common/images/app_spinner.dart';
import 'package:uwearis/features/widgets/common/overlays/error_state_widget.dart';
import 'package:uwearis/features/widgets/magazine/magazine_item_card.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../../helpers/text_scale_harness.dart';
import '../../helpers/widget_harness.dart';

const _summary = MagazineStorySummary(
  id: 4,
  issueId: 3,
  slug: 'old-money',
  format: MagazineFormat.story,
  kicker: 'Style Notes',
  title: 'Old Money Sport',
);

/// Cover + four slides, no photos (tests stay off the network). The
/// selection slide sits in the middle so taps on it can be checked.
const _story = MagazineStory(
  summary: _summary,
  pages: [
    MagazineFeatureSlide(heading: 'Slide one'),
    MagazineSelectionSlide(
      heading: 'Slide two',
      items: [MagazineItem(id: 1, name: 'Track Jacket')],
    ),
    MagazineImmersiveSlide(heading: 'Slide three'),
    MagazineGallerySlide(
      heading: 'Slide four',
      images: [MagazineCaptionedPhoto(), MagazineCaptionedPhoto()],
    ),
  ],
);

void _phone(WidgetTester tester) =>
    applyLayoutCase(tester, (width: 390, scale: 1, locale: const Locale('en')));

/// A launcher page that opens [reader] as the app does, so closing can be
/// checked.
Future<void> _pumpReader(WidgetTester tester, {MagazineStory story = _story}) =>
    pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => EditorialStoryReader(story: story),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ).then((_) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    });

Future<void> _tapAt(WidgetTester tester, double fraction) async {
  final size = tester.getSize(find.byType(PageView));
  await tester.tapAt(Offset(size.width * fraction, size.height / 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the cover; taps on the side thirds page', (
    tester,
  ) async {
    _phone(tester);
    await _pumpReader(tester);
    expect(find.text('Old Money Sport'), findsOneWidget);
    expect(find.text('STYLE NOTES / 01'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 1 of 5'), findsOneWidget);

    await _tapAt(tester, 0.9);
    expect(find.text('Slide one'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 2 of 5'), findsOneWidget);

    await _tapAt(tester, 0.5);
    expect(find.text('Slide one'), findsOneWidget, reason: 'middle third');

    await _tapAt(tester, 0.1);
    expect(find.text('Old Money Sport'), findsOneWidget);

    await _tapAt(tester, 0.1);
    expect(find.text('Old Money Sport'), findsOneWidget, reason: 'first');
  });

  testWidgets('swipes page sideways', (tester) async {
    _phone(tester);
    await _pumpReader(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Slide one'), findsOneWidget);
  });

  testWidgets('taps on the selection slide go to its cards, not paging', (
    tester,
  ) async {
    _phone(tester);
    await _pumpReader(tester);
    await _tapAt(tester, 0.9);
    await _tapAt(tester, 0.9);
    expect(find.byType(MagazineItemCard), findsOneWidget);

    await _tapAt(tester, 0.9);
    expect(find.text('Slide two'), findsOneWidget);
    await _tapAt(tester, 0.1);
    expect(find.text('Slide two'), findsOneWidget);
  });

  testWidgets('stops at the last slide', (tester) async {
    _phone(tester);
    await _pumpReader(tester);
    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
    }
    expect(find.text('Slide four'), findsOneWidget);
    await _tapAt(tester, 0.9);
    expect(find.text('Slide four'), findsOneWidget);
  });

  testWidgets('the progress bar fills one segment per slide reached', (
    tester,
  ) async {
    _phone(tester);
    await _pumpReader(tester);
    List<double> fills() => tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((b) => b.widthFactor!)
        .toList();

    expect(fills(), [1, 0, 0, 0, 0]);
    await _tapAt(tester, 0.9);
    await _tapAt(tester, 0.9);
    expect(fills(), [1, 1, 1, 0, 0]);
  });

  testWidgets('✕ closes the reader', (tester) async {
    _phone(tester);
    await _pumpReader(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorialStoryReader), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('with reduce motion, a tap jumps without animating', (
    tester,
  ) async {
    _phone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpReader(tester);

    final size = tester.getSize(find.byType(PageView));
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pump();
    // One frame later the cover is already gone: no slide transition.
    expect(find.text('Slide one'), findsOneWidget);
    expect(find.text('Old Money Sport'), findsNothing);
  });

  testWidgets('a story with no slide this build can show is unavailable', (
    tester,
  ) async {
    _phone(tester);
    await _pumpReader(tester, story: const MagazineStory(summary: _summary));
    expect(
      find.text("This story can't be shown in this version of the app."),
      findsOneWidget,
    );
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  group('EditorialStoryPage', () {
    testWidgets('shows the card\'s cover while the story loads', (
      tester,
    ) async {
      _phone(tester);
      final pending = Completer<MagazineStory>();
      await pumpApp(
        tester,
        const EditorialStoryPage(storyId: 4, summary: _summary),
        overrides: [
          magazineStoryProvider.overrideWith((ref, key) => pending.future),
        ],
      );
      await tester.pump();
      expect(find.text('Old Money Sport'), findsOneWidget);
      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      pending.complete(_story);
      await tester.pumpAndSettle();
      expect(find.byType(EditorialStoryReader), findsOneWidget);
      expect(find.byType(AppSpinner), findsNothing);
    });

    testWidgets('a failed load offers retry and a way out', (tester) async {
      _phone(tester);
      var calls = 0;
      await pumpApp(
        tester,
        const EditorialStoryPage(storyId: 4),
        overrides: [
          magazineStoryProvider.overrideWith((ref, key) async {
            calls++;
            if (calls == 1) {
              throw const ApiException(statusCode: 404, message: 'gone');
            }
            return _story;
          }),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byType(ErrorStateWidget), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorialStoryReader), findsOneWidget);
    });
  });

  test('the layout gallery shows all eight layouts', () {
    final pages = editorialLayoutGallery(const Locale('en')).pages;
    final labels = pages.map((p) => p.label).toList();
    expect(labels.toSet(), hasLength(labels.length), reason: 'unique names');
    expect(pages.map((p) => p.runtimeType).toSet(), {
      MagazineImmersiveSlide,
      MagazineFeatureSlide,
      MagazineDetailSlide,
      MagazineGallerySlide,
      MagazineListSlide,
      MagazineBreakdownSlide,
      MagazineTypographySlide,
      MagazineSelectionSlide,
    });
    expect(
      pages.whereType<MagazineGallerySlide>().map((g) => g.images.length),
      containsAll([2, 3, 4]),
    );
  });

  test('the mock stories are stories an editor would write', () {
    for (final story in editorialMockStories(const Locale('en'))) {
      final pages = story.pages.length + 1;
      expect(pages, inInclusiveRange(4, 8), reason: story.summary.title);
      expect(story.pages.map((p) => p.label), isNot(contains(contains('·'))));
    }
  });

  testWidgets('photo pages run edge to edge under white system icons and '
      'controls; page-colour pages switch to dark', (tester) async {
    _phone(tester);
    await _pumpReader(tester);
    SystemUiOverlayStyle style() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).last,
        )
        .value;
    Color closeColor() => tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(IconButton),
          ),
        )
        .color!;

    // The cover.
    expect(style().statusBarIconBrightness, Brightness.light);
    expect(style().statusBarColor, Colors.transparent);
    expect(style().systemNavigationBarColor, Colors.transparent);
    expect(closeColor(), AppColors.textOnPrimary);

    await _tapAt(tester, 0.9);
    expect(style().statusBarIconBrightness, Brightness.dark);
    expect(style().statusBarColor, Colors.transparent);
    expect(closeColor(), AppColors.textPrimary);
  });

  testWidgets('past ten pages the progress bar is one bar and a count', (
    tester,
  ) async {
    _phone(tester);
    await _pumpReader(
      tester,
      story: MagazineStory(
        summary: _summary,
        pages: [
          for (var i = 0; i < 11; i++) MagazineFeatureSlide(heading: 'P$i'),
        ],
      ),
    );
    expect(find.text('1 / 12'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsOneWidget);
    await _tapAt(tester, 0.9);
    expect(find.text('2 / 12'), findsOneWidget);
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      closeTo(2 / 12, 0.001),
    );
  });

  testWidgets('credits close the last page, under its content; no info '
      'button', (tester) async {
    _phone(tester);
    await _pumpReader(tester);
    expect(find.text('Credits'), findsNothing, reason: 'no credits');
    Navigator.of(tester.element(find.byType(EditorialStoryReader))).pop();
    await tester.pumpAndSettle();

    final opened = <String>[];
    // A flowing page and a full-screen one, each as the last page.
    for (final last in const [
      MagazineFeatureSlide(heading: 'Words'),
      MagazineTypographySlide(heading: 'Words'),
    ]) {
      await pumpApp(
        tester,
        EditorialStoryReader(
          story: MagazineStory(
            summary: _summary,
            pages: [
              const MagazineFeatureSlide(heading: 'First'),
              last,
            ],
            author: 'Uwearis Editors',
            sources: const [
              MagazineSource(title: 'The video', url: 'https://youtu.be/x'),
            ],
            photoCredits: const ['Ken', 'Aya'],
            aiImageTools: const ['Midjourney v7'],
          ),
          onOpenSource: opened.add,
        ),
      );
      expect(find.byIcon(Icons.info_outline), findsNothing);
      await _tapAt(tester, 0.9);
      expect(
        find.text('Uwearis Editors').hitTestable(),
        findsNothing,
        reason: 'page 2',
      );
      await _tapAt(tester, 0.9);
      expect(find.text('Words'), findsOneWidget);
      final words = tester.getRect(find.text('Words'));
      await tester.ensureVisible(find.text('The video'));
      await tester.pumpAndSettle();
      expect(find.text('Uwearis Editors'), findsOneWidget);
      expect(find.text('Ken、Aya'), findsOneWidget);
      expect(find.text('AI-GENERATED IMAGES'), findsOneWidget);
      expect(find.text('Midjourney v7'), findsOneWidget);
      expect(
        tester.getRect(find.text('Credits')).top,
        greaterThan(words.top),
        reason: '$last',
      );
      await tester.tap(find.text('The video'));
      await tester.pumpAndSettle();
    }
    expect(opened, ['https://youtu.be/x', 'https://youtu.be/x']);
  });

  testWidgets('a dark text page gets light chrome', (tester) async {
    _phone(tester);
    await _pumpReader(
      tester,
      story: const MagazineStory(
        summary: _summary,
        pages: [
          MagazineTypographySlide(heading: 'Light'),
          MagazineTypographySlide(
            heading: 'Dark',
            tone: MagazineSlideTone.dark,
          ),
        ],
      ),
    );
    Color scaffold() =>
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor!;
    await _tapAt(tester, 0.9);
    expect(scaffold(), AppColors.pageBackground);
    await _tapAt(tester, 0.9);
    expect(scaffold(), AppColors.trueBlack);
  });

  group('layout', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await loadAppFont();
      await loadEditorialFont();
    });

    List<MagazineStory> stories(Locale locale) => [
      editorialLayoutGallery(locale),
      ...editorialMockStories(locale),
    ];

    for (final c in layoutCases) {
      testWidgets('previews · ${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c);
        for (final story in stories(c.locale)) {
          await _pumpReader(tester, story: story);
          await _readThrough(tester, story);
        }
      });
    }

    // The shortest screen, and a large one, at the default text size.
    for (final (width, height) in [(320.0, 568.0), (430.0, 932.0)]) {
      testWidgets('previews · ${width.toInt()}×${height.toInt()}', (
        tester,
      ) async {
        final c = (width: width, scale: 1.0, locale: const Locale('en'));
        applyLayoutCase(tester, c, height: height);
        for (final story in stories(c.locale)) {
          await _pumpReader(tester, story: story);
          await _readThrough(tester, story);
        }
      });
    }
  });
}

/// Pages through [story] to its end, checking each slide on the way, then
/// closes it.
Future<void> _readThrough(WidgetTester tester, MagazineStory story) async {
  final count = story.pages.length + 1;
  for (var i = 0; i < count; i++) {
    // Overflow fails the test on its own.
    for (final text in find.byType(Text).evaluate()) {
      expectNoBrokenWords(tester, find.byWidget(text.widget));
    }
    expectWithin(
      tester,
      find.byTooltip(
        AppLocalizations.of(tester.element(find.byType(PageView))).close,
      ),
      find.byType(EditorialStoryReader),
    );
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
  }
  // Every page was reached: the progress bar's last segment is the last
  // page, so the story ends here.
  expect(
    find.bySemanticsLabel(
      AppLocalizations.of(
        tester.element(find.byType(PageView)),
      ).editorialPageLabel(count, count),
    ),
    findsOneWidget,
    reason: story.summary.title,
  );
  await tester.tap(
    find.byTooltip(
      AppLocalizations.of(tester.element(find.byType(PageView))).close,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('open'), findsOneWidget);
}
