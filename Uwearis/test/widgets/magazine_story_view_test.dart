import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis/features/widgets/magazine/magazine_item_card.dart';
import 'package:uwearis/features/widgets/magazine/magazine_story_view.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

const _product = MagazineProduct(
  id: 20,
  brand: 'UNIQLO',
  name: 'Tee',
  price: 590,
  currency: 'TWD',
  productUrl: 'https://shop/tee',
  isAvailable: true,
);

MagazineStory _story({List<MagazineBlock>? blocks}) => MagazineStory(
  summary: const MagazineStorySummary(
    id: 1,
    issueId: 1,
    slug: 'spring-edit',
    title: 'Layers for the trail',
    subtitle: 'Light shells and soft fleece.',
  ),
  blocks:
      blocks ??
      const [
        MagazineHeadingBlock('Start with a shell'),
        MagazineParagraphBlock('A light shell blocks the wind.'),
        MagazineImageBlock(caption: 'On the ridge'),
        MagazineItemGroupBlock(
          title: 'Get the look',
          items: [
            MagazineItem(id: 1, name: 'Windproof Shell', product: _product),
            MagazineItem(id: 2, name: 'Vintage Fleece', brand: 'Patagonia'),
          ],
        ),
      ],
);

Future<void> _pump(
  WidgetTester tester,
  MagazineStory story, {
  void Function(MagazineItem)? onShop,
}) => pumpApp(
  tester,
  Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MagazineStoryView(story: story, onShopItem: onShop),
    ),
  ),
);

void main() {
  testWidgets('a sponsored article says so above its title and credits '
      'everyone at the end', (tester) async {
    applyLayoutCase(tester, (
      width: 390,
      scale: 1,
      locale: const Locale('zh', 'TW'),
    ));
    await _pump(
      tester,
      const MagazineStory(
        summary: MagazineStorySummary(
          id: 1,
          issueId: 1,
          slug: 's',
          title: '秋冬穿搭',
          sponsorship: MagazineSponsorship.gifted,
          sponsorName: 'KUMO',
        ),
        blocks: [MagazineParagraphBlock('第一段')],
        author: '編輯部',
        sources: [MagazineSource(url: 'https://brand.example.com/aw')],
      ),
    );
    final label = tester.getRect(find.text('品牌提供｜KUMO').first);
    expect(label.bottom, lessThan(tester.getRect(find.text('秋冬穿搭')).top));
    expect(find.text('出處資訊'), findsOneWidget);
    expect(find.text('編輯部'), findsOneWidget);
    expect(find.text('brand.example.com'), findsOneWidget, reason: 'no title');
    expect(
      tester.getRect(find.text('出處資訊')).top,
      greaterThan(tester.getRect(find.text('第一段')).bottom),
    );

    await _pump(
      tester,
      const MagazineStory(
        summary: MagazineStorySummary(id: 1, issueId: 1, slug: 's', title: 'T'),
      ),
    );
    expect(find.text('出處資訊'), findsNothing);
  });

  testWidgets('renders the headline and every block', (tester) async {
    applyLayoutCase(tester, (
      width: 390,
      scale: 1,
      locale: const Locale('en'),
    ), height: 2400);
    await _pump(tester, _story());

    for (final text in [
      'Layers for the trail',
      'Light shells and soft fleece.',
      'Start with a shell',
      'A light shell blocks the wind.',
      'On the ridge',
      'Get the look',
      'Windproof Shell',
      'UNIQLO · NT\$590',
      'Vintage Fleece',
      'Patagonia',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('only an item with a product on sale can be bought', (
    tester,
  ) async {
    applyLayoutCase(tester, (
      width: 390,
      scale: 1,
      locale: const Locale('en'),
    ), height: 2400);
    MagazineItem? shopped;
    await _pump(tester, _story(), onShop: (item) => shopped = item);

    expect(find.text('Shop'), findsOneWidget);
    await tester.tap(find.text('Shop'));
    expect(shopped?.id, 1);
  });

  testWidgets('no shop action without a handler (CMS preview)', (tester) async {
    applyLayoutCase(tester, (
      width: 390,
      scale: 1,
      locale: const Locale('en'),
    ), height: 2400);
    await _pump(tester, _story());
    expect(find.text('Shop'), findsNothing);
  });

  testWidgets('a sold-out product shows the brand but no price', (
    tester,
  ) async {
    applyLayoutCase(tester, (
      width: 390,
      scale: 1,
      locale: const Locale('en'),
    ), height: 2400);
    await _pump(
      tester,
      _story(
        blocks: const [
          MagazineItemBlock(
            MagazineItem(
              id: 1,
              name: 'Tee',
              product: MagazineProduct(
                id: 20,
                brand: 'UNIQLO',
                name: 'Tee',
                price: 590,
                currency: 'TWD',
                isAvailable: false,
              ),
            ),
          ),
        ],
      ),
      onShop: (_) {},
    );
    expect(find.text('UNIQLO'), findsOneWidget);
    expect(find.text('Shop'), findsNothing);
  });

  group('layout', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await loadAppFont();
      await loadEditorialFont();
    });

    for (final c in layoutCases) {
      testWidgets(describeCase(c), (tester) async {
        applyLayoutCase(tester, c, height: 3200);
        await _pump(tester, _story(), onShop: (_) {});

        for (final text in find.byType(Text).evaluate()) {
          expectNoBrokenWords(tester, find.byWidget(text.widget));
        }
        // Long Latin names stack the cards instead of splitting a word.
        final cards = find.byType(MagazineItemCard);
        final first = tester.getRect(cards.at(0));
        final second = tester.getRect(cards.at(1));
        final paired = first.top == second.top;
        expect(paired || second.top >= first.bottom, isTrue);
      });
    }
  });
}
