import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/pages/outfit_edit_page.dart';
import 'package:uwearis/features/widgets/common/cards/app_list_card.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';

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

  // Tall enough that every ListView row is built.
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
      expect(find.text('OUTFIT ITEMS'), findsOneWidget);
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
      OutfitEditResult? poppedResult;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.push<OutfitEditResult>(
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

      // The only AppListCard is the "Add Garment" row; it opens Shoes, the
      // only category in this pool with room left.
      await tester.tap(find.byType(AppListCard));
      await tester.pumpAndSettle();
      expect(find.text('Edit Garment'), findsNothing);
      await tester.tap(find.text('Sneakers'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.byType(OutfitEditPage), findsNothing);
      expect(poppedResult?.garmentIds, {1, 2, 3});
      expect(poppedResult?.backgroundId, isNull);
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

      await tester.tap(find.text('Tee'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Garment'), findsOneWidget);
      expect(find.text('Polo'), findsOneWidget);
      await tester.tap(find.text('Polo'));
      await tester.pumpAndSettle();

      expect(find.text('Polo'), findsOneWidget);
      expect(find.text('Tee'), findsNothing);
      expect(find.text('Confirm'), findsOneWidget);
    },
  );

  group('base-layer top exclusivity (same rules as Add Outfit)', () {
    final wardrobe = [
      _garment(
        id: 1,
        category: GarmentCategory.top,
        name: 'Tee',
        subCategory: 'T-shirt',
      ),
      _garment(
        id: 2,
        category: GarmentCategory.top,
        name: 'Polo',
        subCategory: 'Polo shirt',
      ),
      _garment(
        id: 3,
        category: GarmentCategory.top,
        name: 'Cardi',
        subCategory: 'Cardigan',
      ),
    ];

    testWidgets(
      'Add garment hides the worn top\'s base-layer alternative, but a '
      'genuine mid-layer piece still shows and stacks',
      (tester) async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitEditPage(
            preloadedGarments: wardrobe,
            initialGarments: [wardrobe[0]],
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        expect(find.text('Polo'), findsNothing);
        expect(find.text('Cardi'), findsOneWidget);

        await tester.tap(find.text('Cardi'));
        await tester.pumpAndSettle();

        expect(find.text('Top · T-shirt'), findsOneWidget);
        expect(find.text('Top · Cardigan'), findsOneWidget);
      },
    );

    testWidgets(
      'swapping the worn top offers its base-layer alternative, and picking '
      'it replaces the top rather than adding a mid layer',
      (tester) async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitEditPage(
            preloadedGarments: wardrobe,
            initialGarments: [wardrobe[0]],
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Tee'));
        await tester.pumpAndSettle();
        expect(find.text('Polo'), findsOneWidget);

        await tester.tap(find.text('Polo'));
        await tester.pumpAndSettle();

        expect(find.text('Tee'), findsNothing);
        expect(find.text('Top · Polo shirt'), findsOneWidget);
      },
    );
  });

  testWidgets('a garment row thumbnail fills its slot, same as Add Outfit\'s', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      OutfitEditPage(
        preloadedGarments: suitcase,
        initialGarments: [suitcase.first],
      ),
    );
    await tester.pump();

    // 78 wide x 84 tall slot, minus the 8px padding on every side.
    expect(tester.getSize(find.byType(GarmentImage)), const Size(62, 68));
  });

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
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Tee'), findsNothing);
    expect(find.text('Jeans'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  group('showBackgroundPicker (Outfit Details\' new-version flow)', () {
    Future<OutfitEditResult?> pumpAndConfirm(
      WidgetTester tester, {
      int? initialBackgroundId,
      required Future<void> Function() interact,
    }) async {
      OutfitEditResult? popped;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.push<OutfitEditResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OutfitEditPage(
                      preloadedGarments: suitcase,
                      initialGarments: [suitcase[0], suitcase[1]],
                      showBackgroundPicker: true,
                      initialBackgroundId: initialBackgroundId,
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
      await interact();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      return popped;
    }

    testWidgets('preselects the source version\'s background', (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitEditPage(
          preloadedGarments: suitcase,
          initialGarments: [suitcase.first],
          showBackgroundPicker: true,
          initialBackgroundId: 7,
        ),
      );
      await tester.pump();

      expect(find.text('BACKGROUND'), findsOneWidget);
      expect(find.text('Tokyo Street'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
      // Sits below the outfit items, behind a divider.
      expect(
        tester.getTopLeft(find.text('BACKGROUND')).dy,
        greaterThan(tester.getTopLeft(find.text('OUTFIT ITEMS')).dy),
      );
      expect(find.byType(AppDivider), findsWidgets);

      await tester.tap(find.text('Tokyo Street'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets(
      'changing only the background enables Confirm and pops its id',
      (tester) async {
        useTallSurface(tester);
        final result = await pumpAndConfirm(
          tester,
          initialBackgroundId: 7,
          interact: () async {
            await tester.tap(find.text('Tokyo Street'));
            await tester.pumpAndSettle();
            expect(find.text('Confirm'), findsNothing);
            await tester.tap(find.text('Paris Street'));
            await tester.pumpAndSettle();
          },
        );

        expect(result?.garmentIds, {1, 2});
        expect(result?.backgroundId, 6);
      },
    );

    testWidgets('keeps the source background when only garments change', (
      tester,
    ) async {
      useTallSurface(tester);
      final result = await pumpAndConfirm(
        tester,
        initialBackgroundId: 7,
        interact: () async {
          await tester.tap(find.byType(AppListCard));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sneakers'));
          await tester.pumpAndSettle();
        },
      );

      expect(result?.garmentIds, {1, 2, 3});
      expect(result?.backgroundId, 7);
    });
  });
}
