import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
