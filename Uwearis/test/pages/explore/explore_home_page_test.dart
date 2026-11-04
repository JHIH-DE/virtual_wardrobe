import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/explore/explore_home_page.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/text_scale_harness.dart';
import '../../helpers/widget_harness.dart';

Future<void> _loadSerif() async {
  for (final (family, file) in [
    ('Newsreader_regular', 'Regular'),
    ('Newsreader_600', 'SemiBold'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/google_fonts/Newsreader-$file.ttf'));
    await loader.load();
  }
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets('shows the story and both product cards', (tester) async {
    applyLayoutCase(tester, (
      width: 390,
      scale: 1,
      locale: const Locale('en'),
    ), height: 1400);
    await pumpApp(tester, const ExploreHomePage());

    for (final text in [
      'THE EDIT',
      'One blazer, three ways',
      'A smarter way to dress for the week.',
      'Read the story',
      'Works with your wardrobe',
      'See all',
      'Navy Blazer',
      'Pairs with your grey trousers.',
      'Ivory Sneakers',
      'Pairs with your straight jeans.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (final asset in [
      'assets/images/explore_01.jpg',
      'assets/images/explore_02.jpg',
      'assets/images/explore_03.png',
    ]) {
      expect(find.image(AssetImage(asset)), findsOneWidget, reason: asset);
    }
  });

  group('layout', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await loadAppFont();
      await _loadSerif();
    });

    for (final c in layoutCases) {
      testWidgets(describeCase(c), (tester) async {
        applyLayoutCase(tester, c, height: 2400);
        await pumpApp(tester, const ExploreHomePage());

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
