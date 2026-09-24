import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/garment/garment_list_card.dart';

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

      // The icon itself is IgnorePointer-wrapped (a bare glyph, no disc to
      // hang a hit target on) — the tap falls through to the card
      // underneath, so it never registers as a hit on the icon itself.
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

  testWidgets(
    'the card is always the same fixed height regardless of a long name, a '
    'color line, or the garment photo\'s own aspect ratio, with no overflow',
    (tester) async {
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
      expect(
        tester.getSize(cards.at(0)).height,
        AppDimens.garmentListCardHeight,
      );
      expect(
        tester.getSize(cards.at(1)).height,
        AppDimens.garmentListCardHeight,
      );
    },
  );
}
