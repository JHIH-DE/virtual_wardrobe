import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/outfit_edit_page.dart';
import 'package:uwearis/features/widgets/common/cards/app_list_card.dart';

import '../helpers/widget_harness.dart';

Garment _garment({
  required int id,
  required GarmentCategory category,
  String name = 'Item',
  String subCategory = '',
}) {
  return Garment(
    id: id,
    garmentId: id,
    name: name,
    category: category,
    subCategory: subCategory,
    uploadUrl: '',
    objectName: '',
  );
}

void main() {
  final suitcase = [
    _garment(id: 1, category: GarmentCategory.top, name: 'Tee'),
    _garment(id: 2, category: GarmentCategory.bottom, name: 'Jeans'),
    _garment(id: 3, category: GarmentCategory.shoes, name: 'Sneakers'),
  ];

  // A viewport tall enough that the whole ListView is laid out at once, so
  // every row is in the tree.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'shows the Add Outfit-style vertical list, not Match a Look or Background',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitEditPage(
          preloadedGarments: suitcase,
          initialGarments: [suitcase.first],
        ),
      );
      await tester.pump();

      expect(find.text('Match a Look'), findsNothing);
      expect(find.text('BACKGROUND'), findsNothing);
      expect(
        find.text("Choose which suitcase items make up this day's outfit."),
        findsOneWidget,
      );
      expect(find.text('YOUR OUTFIT'), findsOneWidget);
      expect(find.text('Add Garment'), findsOneWidget);
      expect(find.text('Tee'), findsOneWidget);
      // Confirm stays hidden until the selection actually changes.
      expect(find.text('Confirm'), findsNothing);
    },
  );

  testWidgets(
    'a garment id missing from validGarmentIds gets a warning badge',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitEditPage(
          preloadedGarments: suitcase,
          initialGarments: [suitcase[0]],
          // Tee (id 1) is no longer actually packed.
          validGarmentIds: const {2, 3},
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.error), findsOneWidget);
    },
  );

  testWidgets(
    'Confirm appears once the selection changes, and pops the picked ids',
    (tester) async {
      useTallSurface(tester);
      Set<int>? poppedResult;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.push<Set<int>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OutfitEditPage(
                      preloadedGarments: suitcase,
                      initialGarments: [suitcase[0], suitcase[1]],
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsNothing);

      // AppListCard is only used for the pinned "Add Garment" row now (every
      // picked garment renders as a plain card instead) — Top/Bottom are
      // already picked, so it opens straight to whatever category still has
      // room (Shoes, since Outer/One-piece/Accessory aren't in this
      // fixture's pool).
      await tester.tap(find.byType(AppListCard));
      await tester.pumpAndSettle();
      // The pinned add row's own picker keeps the plain "Add Garment"
      // title — "Edit Garment" is reserved for swapping an existing card.
      expect(find.text('Edit Garment'), findsNothing);
      await tester.tap(find.text('Sneakers'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.byType(OutfitEditPage), findsNothing);
      expect(poppedResult, {1, 2, 3});
    },
  );

  testWidgets(
    'tapping an existing card reopens the picker to swap it, pinned to that '
    'category',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitEditPage(
          preloadedGarments: [
            ...suitcase,
            _garment(id: 4, category: GarmentCategory.top, name: 'Polo'),
          ],
          initialGarments: [suitcase[0]],
        ),
      );
      await tester.pump();

      // Tap the Tee row itself (not the pinned Add Garment row).
      await tester.tap(find.text('Tee'));
      await tester.pumpAndSettle();

      // Swapping an existing card reads as "Edit Garment", not "Add
      // Garment" — that title is reserved for the pinned add row.
      expect(find.text('Edit Garment'), findsOneWidget);
      expect(find.text('Polo'), findsOneWidget);
      await tester.tap(find.text('Polo'));
      await tester.pumpAndSettle();

      expect(find.text('Polo'), findsOneWidget);
      expect(find.text('Tee'), findsNothing);
      expect(find.text('Confirm'), findsOneWidget);
    },
  );

  testWidgets('the ✕ badge removes a card from the outfit', (tester) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      OutfitEditPage(
        preloadedGarments: suitcase,
        initialGarments: [suitcase[0], suitcase[1]],
      ),
    );
    await tester.pump();

    expect(find.text('Tee'), findsOneWidget);
    // Two ✕ badges (Tee + Jeans) — remove the first one.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Tee'), findsNothing);
    expect(find.text('Jeans'), findsOneWidget);
    // Still has Jeans selected, so Confirm shows now that the set changed.
    expect(find.text('Confirm'), findsOneWidget);
  });
}
