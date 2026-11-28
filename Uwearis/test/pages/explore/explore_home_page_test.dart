import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/magazine_provider.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis/features/pages/explore/editorial_story_page.dart';
import 'package:uwearis/features/pages/explore/explore_home_page.dart';
import 'package:uwearis/features/widgets/magazine/magazine_network_photo.dart';
import 'package:uwearis/features/pages/explore/magazine_story_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/overlays/error_state_widget.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/magazine_fakes.dart';
import '../../helpers/text_scale_harness.dart';
import '../../helpers/widget_harness.dart';

Finder _inCarousel(Finder finder) =>
    find.descendant(of: find.byType(PageView), matching: finder);

void _phone(WidgetTester tester) => applyLayoutCase(tester, (
  width: 390,
  scale: 1,
  locale: const Locale('en'),
), height: 1400);

void main() {
  setUp(setUpFakeAuth);

  testWidgets('shows the latest issue, its first story and the mock sections', (
    tester,
  ) async {
    _phone(tester);
    await pumpApp(
      tester,
      const ExploreHomePage(),
      overrides: [fakeMagazineHomeOverride()],
    );
    await tester.pumpAndSettle();

    for (final text in [
      'One blazer, three ways',
      'A smarter way to dress for the week.',
      'Read',
    ]) {
      expect(_inCarousel(find.text(text)), findsOneWidget, reason: text);
    }
    for (final text in [
      'THE EDIT',
      'ISSUE 14 — NOV 2026',
      'The Outdoor Issue',
      'Outdoor style for everyday life.',
      'Style Guide',
      'The Selection',
      'Lifestyle',
      'Match Your Wardrobe',
      'Navy Blazer',
      'Ivory Sneakers',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('swiping the edit moves to the next story', (tester) async {
    _phone(tester);
    await pumpApp(
      tester,
      const ExploreHomePage(),
      overrides: [fakeMagazineHomeOverride()],
    );
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(_inCarousel(find.text('Rugged meets relaxed')), findsOneWidget);
  });

  testWidgets('the women switch shows the women\'s stories', (tester) async {
    _phone(tester);
    await pumpApp(
      tester,
      const ExploreHomePage(),
      overrides: [fakeMagazineHomeOverride()],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Women'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(_inCarousel(find.text('Soft layers for the city')), findsOneWidget);
    expect(find.text('Rugged meets relaxed'), findsNothing);
  });

  testWidgets('no published issue yet', (tester) async {
    _phone(tester);
    await pumpApp(
      tester,
      const ExploreHomePage(),
      overrides: [fakeMagazineHomeOverride((_) => const MagazineHome())],
    );
    await tester.pumpAndSettle();

    expect(find.text('The next issue is on its way.'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('Match Your Wardrobe'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    _phone(tester);
    var failing = true;
    await pumpApp(
      tester,
      const ExploreHomePage(),
      overrides: [
        magazineHomeProvider.overrideWith((ref, key) async {
          if (failing) {
            throw const ApiException(statusCode: 500, message: 'boom');
          }
          return fakeMagazineHome(key.audience);
        }),
      ],
    );
    // Lets the provider's own retries run out.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(ErrorStateWidget), findsOneWidget);

    failing = false;
    await tester.tap(
      find.descendant(
        of: find.byType(ErrorStateWidget),
        matching: find.byType(AccentPillButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(_inCarousel(find.text('One blazer, three ways')), findsOneWidget);
  });

  testWidgets('Read opens the story', (tester) async {
    _phone(tester);
    await pumpApp(
      tester,
      const ExploreHomePage(),
      overrides: [
        fakeMagazineHomeOverride(),
        magazineStoryProvider.overrideWith(
          (ref, key) async => MagazineStory(
            summary: fakeMagazineHome(MagazineAudience.men).stories.first,
            blocks: const [MagazineParagraphBlock('Start with the blazer.')],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(_inCarousel(find.text('Read')).first);
    await tester.pumpAndSettle();

    expect(find.byType(MagazineStoryPage), findsOneWidget);
    expect(find.text('Start with the blazer.'), findsOneWidget);
  });

  testWidgets('a sponsored story is labelled, and a story opens the reader', (
    tester,
  ) async {
    _phone(tester);
    const story = MagazineStorySummary(
      id: 9,
      issueId: 1,
      slug: 'kumo',
      format: MagazineFormat.story,
      title: 'Kumo Atelier',
      sponsorship: MagazineSponsorship.advertisement,
      sponsorName: 'KUMO',
    );
    await pumpApp(
      tester,
      const ExploreHomePage(),
      overrides: [
        fakeMagazineHomeOverride(
          (_) => MagazineHome(
            issue: fakeMagazineHome(MagazineAudience.all).issue,
            stories: const [story],
          ),
        ),
        magazineStoryProvider.overrideWith(
          (ref, key) async => const MagazineStory(
            summary: story,
            pages: [MagazineTypographySlide(heading: 'Less, but better.')],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(_inCarousel(find.text('Advertisement | KUMO')), findsWidgets);

    await tester.tap(_inCarousel(find.text('Read')).first);
    await tester.pumpAndSettle();
    expect(find.byType(EditorialStoryReader), findsOneWidget);
    expect(find.byType(MagazineStoryPage), findsNothing);
    expect(find.text('Advertisement | KUMO'), findsOneWidget, reason: 'cover');
  });

  for (final withCard in [true, false]) {
    testWidgets(
      'the card shows ${withCard ? "the story's card image" : "its cover without one"}',
      (tester) async {
        _phone(tester);
        const cover = MagazinePhoto(url: 'https://x/cover.jpg');
        const card = MagazinePhoto(url: 'https://x/card.jpg', focalX: -0.3);
        await pumpApp(
          tester,
          const ExploreHomePage(),
          overrides: [
            fakeMagazineHomeOverride(
              (_) => MagazineHome(
                issue: fakeMagazineHome(MagazineAudience.all).issue,
                stories: [
                  MagazineStorySummary(
                    id: 1,
                    issueId: 1,
                    slug: 's',
                    title: 'Story',
                    cover: cover,
                    card: withCard ? card : null,
                  ),
                ],
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();
        final shown = [
          for (final photo in tester.widgetList<MagazineNetworkPhoto>(
            _inCarousel(find.byType(MagazineNetworkPhoto)),
          ))
            ?photo.photo?.url,
        ];
        expect(shown, [withCard ? card.url : cover.url]);
      },
    );
  }

  group('layout', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await loadAppFont();
      await loadEditorialFont();
    });

    for (final c in layoutCases) {
      testWidgets(describeCase(c), (tester) async {
        applyLayoutCase(tester, c, height: 2400);
        await pumpApp(
          tester,
          const ExploreHomePage(),
          overrides: [fakeMagazineHomeOverride()],
        );
        await tester.pumpAndSettle();

        final texts = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Text),
        );
        for (final text in texts.evaluate()) {
          expectNoBrokenWords(tester, find.byWidget(text.widget));
        }
      });
    }
  });
}
