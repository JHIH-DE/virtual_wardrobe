import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';
import 'package:uwearis/features/widgets/garment/garment_list_card.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

Garment _garment({bool isDeleted = false}) {
  return Garment(
    id: 1,
    name: 'Denim Jacket',
    category: GarmentCategory.outer,
    subCategory: 'Denim jacket',
    uploadUrl: '',
    objectName: '',
    imageUrl: '',
    isDeleted: isDeleted,
  );
}

void main() {
  testWidgets('an active garment shows no warning badge', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: GarmentListCard(garment: _garment(), onTap: () {}),
      ),
    );

    expect(find.byIcon(Icons.error), findsNothing);
  });

  testWidgets(
    'a soft-deleted garment shows a warning badge that still triggers onTap',
    (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: GarmentListCard(
            garment: _garment(isDeleted: true),
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.byIcon(Icons.error), findsOneWidget);

      // The icon is IgnorePointer-wrapped; the tap falls through to the card.
      await tester.tap(find.byIcon(Icons.error), warnIfMissed: false);
      expect(taps, 1);
    },
  );

  testWidgets('tapping anywhere else on the card also fires onTap', (
    tester,
  ) async {
    var taps = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: GarmentListCard(garment: _garment(), onTap: () => taps++),
      ),
    );

    await tester.tap(find.text('Denim Jacket'));
    expect(taps, 1);
  });

  testWidgets('at the default text size every row is the same (minimum) height '
      'regardless of a long name or a color line, with no overflow', (
    tester,
  ) async {
    final long = Garment(
      id: 2,
      name: 'Minimalist Oversized Cotton T-Shirt with Contrast Stitching',
      color: 'White',
      category: GarmentCategory.top,
      subCategory: 'T-shirt',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
    );
    final short = _garment();

    await pumpApp(
      tester,
      Scaffold(
        body: Column(
          children: [
            GarmentListCard(garment: long, onTap: () {}),
            GarmentListCard(garment: short, onTap: () {}),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final cards = find.byType(GarmentListCard);
    expect(tester.getSize(cards.at(0)).height, AppDimens.garmentListCardHeight);
    expect(tester.getSize(cards.at(1)).height, AppDimens.garmentListCardHeight);
  });

  testWidgets('every card fills the list width, whatever its name length', (
    tester,
  ) async {
    Garment named(int id, String name) => Garment(
      id: id,
      name: name,
      category: GarmentCategory.top,
      subCategory: 'T-shirt',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
    );
    await pumpApp(
      tester,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GarmentListCard(garment: named(1, 'Cap'), onTap: () {}),
            GarmentListCard(
              garment: named(2, 'Oversized White Graphic T-Shirt with Print'),
              onTap: () {},
            ),
            // Soft-deleted: the warning badge's Stack must not shrink it.
            GarmentListCard(
              garment: named(3, 'Tee').copyWith(isDeleted: true),
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final listWidth = tester.getSize(find.byType(ListView)).width - 32;
    // Measure the visible card (its tappable chrome), not GarmentListCard's
    // outer Stack, which is always full width.
    final cards = find.byType(GarmentListCard);
    for (var i = 0; i < 3; i++) {
      final chrome = find
          .descendant(of: cards.at(i), matching: find.byType(GestureDetector))
          .first;
      expect(tester.getSize(chrome).width, listWidth);
    }
  });

  group('enlarged text', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      testWidgets('a long name and its color stay readable at '
          '${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c);
        final zh = c.locale.languageCode == 'zh';
        final garment = Garment(
          id: 3,
          name: zh
              ? '超大版型復古水洗牛仔卡車外套'
              : 'Oversized Vintage Wash Denim Trucker Jacket',
          color: zh ? '淺藍' : 'Light Blue',
          category: GarmentCategory.outer,
          subCategory: 'Denim jacket',
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
        );
        var taps = 0;
        await pumpApp(
          tester,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GarmentListCard(garment: garment, onTap: () => taps++),
              ],
            ),
          ),
        );

        final card = find.byType(GarmentListCard);
        final name = find.text(garment.name);
        final color = find.text(garment.color!);
        final cardHeight = tester.getSize(card).height;
        expect(
          cardHeight,
          greaterThanOrEqualTo(AppDimens.garmentListCardHeight),
        );
        for (final part in [find.byType(CategoryTag), name, color]) {
          expectWithin(tester, part, card);
        }
        expect(isTruncated(tester, color), isFalse);

        // Below the threshold: one line, like every other row. From it: a
        // name that doesn't fit one line gets a second before any ellipsis.
        final lines = renderedLineCount(tester, name);
        if (c.scale < GarmentListCard.twoLineNameScale) {
          expect(lines, 1);
        } else if (isTruncated(tester, name)) {
          expect(lines, 2);
        }

        // The photo keeps spanning the card (minus its 8px inset) as the
        // card grows, rather than staying a fixed-height strip.
        expect(
          tester.getSize(find.byType(GarmentImage)).height,
          closeTo(cardHeight - 16, 0.5),
        );

        await tester.tap(name);
        expect(taps, 1);
      });
    }
  });
}
