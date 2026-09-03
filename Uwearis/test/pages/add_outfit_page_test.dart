import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/add_outfit_page.dart';

import '../helpers/widget_harness.dart';

Garment _garment({
  required int id,
  required GarmentCategory category,
  String name = 'Item',
}) {
  return Garment(
    id: id,
    garmentId: id,
    name: name,
    category: category,
    subCategory: '',
    uploadUrl: '',
    objectName: '',
  );
}

void main() {
  // preloadedGarments short-circuits the initState network fetch, so the
  // page renders without any HTTP mocking.
  final closet = [
    _garment(id: 1, category: GarmentCategory.top, name: 'Tee'),
    _garment(id: 2, category: GarmentCategory.bottom, name: 'Jeans'),
    _garment(id: 3, category: GarmentCategory.shoes, name: 'Sneakers'),
  ];

  // A viewport tall enough that the whole ListView is laid out at once, so
  // slots/customization below the first screenful are in the tree.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('create mode shows Match a Look and a slot per closet category', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
    await tester.pump();

    expect(find.text('Match a Look'), findsOneWidget);
    expect(find.text('Choose the pieces you want to wear.'), findsOneWidget);
    // One slot row per category present in the closet (FieldLabel upper-cases).
    expect(find.text('TOP'), findsOneWidget);
    expect(find.text('BOTTOM'), findsOneWidget);
    expect(find.text('SHOES'), findsOneWidget);

    // Nothing picked yet, so the Create Outfit bar is gated off (hidden,
    // not greyed) — see BottomActionButton._isUnavailable.
    expect(find.text('Create Outfit'), findsNothing);
    expect(
      find.byKey(const ValueKey('bottomActionButton-hidden')),
      findsOneWidget,
    );
  });

  testWidgets('selectOnly mode drops Match a Look and uses the edit copy', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        preloadedGarments: closet,
        initialGarments: [closet.first],
        selectOnly: true,
      ),
    );
    await tester.pump();

    expect(find.text('Match a Look'), findsNothing);
    expect(
      find.text("Choose which suitcase items make up this day's outfit."),
      findsOneWidget,
    );
    // Confirm stays hidden until the selection actually changes.
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('the customization block only offers Background outside selectOnly', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
    await tester.pump();
    expect(find.text('Accessories & Background'), findsOneWidget);
    expect(find.text('BACKGROUND'), findsOneWidget);
  });

  testWidgets('selectOnly customization block drops the Background section', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        preloadedGarments: closet,
        initialGarments: [closet.first],
        selectOnly: true,
      ),
    );
    await tester.pump();
    expect(find.text('BACKGROUND'), findsNothing);
  });
}
