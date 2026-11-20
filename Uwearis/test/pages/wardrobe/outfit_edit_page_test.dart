import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/wardrobe/outfit_edit_page.dart';
import 'package:uwearis/features/pages/wardrobe/select_garment_page.dart';
import 'package:uwearis/features/widgets/common/cards/app_list_card.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';

import '../../helpers/widget_harness.dart';

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

  group('tops (up to two, no fixed top / mid layer)', () {
    final tee = _garment(
      id: 11,
      category: GarmentCategory.top,
      name: 'Tee',
      subCategory: 'T-shirt',
    );
    final hoodie = _garment(
      id: 12,
      category: GarmentCategory.top,
      name: 'Hoodie',
      subCategory: 'Hoodie',
    );
    final cardi = _garment(
      id: 13,
      category: GarmentCategory.top,
      name: 'Cardi',
      subCategory: 'Cardigan',
    );

    Finder rowOf(String name) => find
        .ancestor(of: find.text(name), matching: find.byType(GestureDetector))
        .first;

    testWidgets('removing the first top keeps the second, and re-adding it '
        'counts as unchanged', (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitEditPage(
          preloadedGarments: [hoodie, tee],
          initialGarments: [hoodie, tee],
        ),
      );
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: rowOf('Hoodie'),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hoodie'), findsNothing);
      expect(find.text('Top · T-shirt'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);

      await tester.tap(find.byType(AppListCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoodie'));
      await tester.pumpAndSettle();

      expect(find.text('Top · Hoodie'), findsOneWidget);
      expect(find.text('Top · T-shirt'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('swapping the second top replaces only that one', (
      tester,
    ) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitEditPage(
          preloadedGarments: [tee, cardi, hoodie],
          initialGarments: [tee, cardi],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Cardi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoodie'));
      await tester.pumpAndSettle();

      expect(find.text('Cardi'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Tee')).dy,
        lessThan(tester.getTopLeft(find.text('Hoodie')).dy),
      );
    });
  });

  group('selection rules', () {
    Garment top(int id, String name, String sub) => _garment(
      id: id,
      category: GarmentCategory.top,
      name: name,
      subCategory: sub,
    );
    Garment acc(int id, String name, String sub) => _garment(
      id: id,
      category: GarmentCategory.accessory,
      name: name,
      subCategory: sub,
    );

    final tee = top(1, 'Tee', 'T-shirt');
    final cardi = top(2, 'Cardi', 'Cardigan');
    final hoodie = top(3, 'Hoodie', 'Hoodie');
    final jacket = _garment(
      id: 4,
      category: GarmentCategory.outer,
      name: 'Jacket',
    );
    final jeans = _garment(
      id: 5,
      category: GarmentCategory.bottom,
      name: 'Jeans',
    );
    final chinos = _garment(
      id: 6,
      category: GarmentCategory.bottom,
      name: 'Chinos',
    );
    final dress = _garment(
      id: 7,
      category: GarmentCategory.onePiece,
      name: 'Dress',
    );
    final sneakers = _garment(
      id: 8,
      category: GarmentCategory.shoes,
      name: 'Sneakers',
    );
    final boots = _garment(
      id: 9,
      category: GarmentCategory.shoes,
      name: 'Boots',
    );
    final hat = acc(21, 'Hat', 'Hat');
    final belt = acc(22, 'Belt', 'Belt');
    final watch = acc(23, 'Watch', 'Watch');
    final necklace = acc(24, 'Necklace', 'Necklace');
    final scarf = acc(25, 'Scarf', 'Scarf');
    final belt2 = acc(26, 'Belt Two', 'Belt');
    final socks = _garment(
      id: 27,
      category: GarmentCategory.socks,
      name: 'Ankle Socks',
    );

    /// Pushes the page over a stub; [popped] holds what it pops, as the
    /// list Trip Details / Trip Outfit Details send as `garment_ids`.
    Future<List<int>? Function()> open(
      WidgetTester tester, {
      required List<Garment> pool,
      List<Garment> initial = const [],
    }) async {
      useTallSurface(tester);
      Set<int>? result;
      var popped = false;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<Set<int>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OutfitEditPage(
                      preloadedGarments: pool,
                      initialGarments: initial,
                    ),
                  ),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () {
        expect(popped, isTrue, reason: 'page has not popped');
        return result?.toList();
      };
    }

    Finder rowOf(String name) => find
        .ancestor(of: find.text(name), matching: find.byType(GestureDetector))
        .first;

    Future<void> remove(WidgetTester tester, String name) async {
      await tester.tap(
        find.descendant(of: rowOf(name), matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String name) async {
      await tester.tap(
        find.descendant(
          of: find.byType(SelectGarmentPage),
          matching: find.text(name),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }

    Finder inPicker(String text) => find.descendant(
      of: find.byType(SelectGarmentPage),
      matching: find.text(text),
    );

    void expectRowOrder(WidgetTester tester, List<String> names) {
      final ys = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
      for (var i = 1; i < ys.length; i++) {
        expect(
          ys[i],
          greaterThan(ys[i - 1]),
          reason: '${names[i]} should sit below ${names[i - 1]}',
        );
      }
    }

    testWidgets('initial garments: tops, outer, bottom, one-piece, shoes, then '
        'accessories in given order — two tops, one per single slot, four '
        'accessories; garment_ids follow the same order', (tester) async {
      final result = await open(
        tester,
        pool: const [],
        initial: [
          belt,
          sneakers,
          tee,
          jeans,
          jacket,
          cardi,
          hoodie,
          chinos,
          hat,
          socks,
          watch,
          necklace,
          dress,
          boots,
        ],
      );

      for (final n in [
        'Tee',
        'Cardi',
        'Jacket',
        'Jeans',
        'Dress',
        'Sneakers',
        'Belt',
        'Hat',
        'Ankle Socks',
        'Watch',
      ]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      for (final n in ['Hoodie', 'Chinos', 'Boots', 'Necklace']) {
        expect(find.text(n), findsNothing, reason: n);
      }
      expectRowOrder(tester, [
        'Tee',
        'Cardi',
        'Jacket',
        'Jeans',
        'Dress',
        'Sneakers',
        'Belt',
        'Hat',
        'Ankle Socks',
        'Watch',
      ]);
      expect(find.text('Confirm'), findsNothing);

      await remove(tester, 'Ankle Socks');
      await confirm(tester);
      expect(result(), [1, 2, 4, 5, 7, 8, 22, 21, 23]);
    });

    testWidgets('two tops fill the top slot: Add Garment offers no third', (
      tester,
    ) async {
      await open(
        tester,
        pool: [tee, cardi, hoodie, jeans],
        initial: [tee, cardi],
      );

      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectGarmentPage), findsOneWidget);
      expect(inPicker('Hoodie'), findsNothing);
      expect(inPicker('Top'), findsNothing);
      expect(inPicker('Jeans'), findsOneWidget);
    });

    testWidgets(
      'a filled single slot is not offered by Add Garment; bottom and '
      'one-piece are separate slots',
      (tester) async {
        await open(tester, pool: [jeans, chinos, dress], initial: [jeans]);

        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        expect(inPicker('Chinos'), findsNothing);
        expect(inPicker('Dress'), findsOneWidget);
        await pick(tester, 'Dress');

        expect(find.text('Jeans'), findsOneWidget);
        expect(find.text('Dress'), findsOneWidget);
      },
    );

    testWidgets(
      'four accessories: Add Garment is exhausted; removing one makes room '
      'and the next pick goes last',
      (tester) async {
        final result = await open(
          tester,
          pool: [hat, belt, watch, necklace, scarf],
          initial: [hat, belt, watch, necklace],
        );

        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        expect(find.byType(SelectGarmentPage), findsNothing);

        await remove(tester, 'Belt');
        expect(find.text('Belt'), findsNothing);
        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        expect(inPicker('Scarf'), findsOneWidget);
        expect(inPicker('Belt'), findsOneWidget);
        expect(inPicker('Hat'), findsNothing);
        await pick(tester, 'Scarf');

        expectRowOrder(tester, ['Hat', 'Watch', 'Necklace', 'Scarf']);
        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        expect(find.byType(SelectGarmentPage), findsNothing);

        await confirm(tester);
        expect(result(), [21, 23, 24, 25]);
      },
    );

    testWidgets(
      'below four, the add-slot stays: picks append one at a time up to four',
      (tester) async {
        final result = await open(
          tester,
          pool: [jeans, hat, belt, watch, necklace],
          initial: [jeans],
        );

        for (final n in ['Watch', 'Hat', 'Necklace', 'Belt']) {
          await tester.tap(find.text('Add Garment'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(SelectGarmentPage),
              matching: find.text('Accessory'),
            ),
          );
          await tester.pumpAndSettle();
          await pick(tester, n);
        }
        expectRowOrder(tester, ['Jeans', 'Watch', 'Hat', 'Necklace', 'Belt']);
        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        expect(find.byType(SelectGarmentPage), findsNothing);

        await confirm(tester);
        expect(result(), [5, 23, 21, 24, 22]);
      },
    );

    testWidgets(
      'swapping an accessory keeps its place; only the swapped row re-admits '
      'its type',
      (tester) async {
        final result = await open(
          tester,
          pool: [hat, belt, watch, belt2, scarf],
          initial: [hat, belt, watch],
        );

        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        expect(inPicker('Scarf'), findsOneWidget);
        expect(inPicker('Belt Two'), findsNothing);
        Navigator.of(tester.element(find.byType(SelectGarmentPage))).pop();
        await tester.pumpAndSettle();
        expect(find.text('Confirm'), findsNothing);

        await tester.tap(find.text('Belt'));
        await tester.pumpAndSettle();
        expect(find.text('Edit Garment'), findsOneWidget);
        expect(inPicker('Belt Two'), findsOneWidget);
        await pick(tester, 'Belt Two');

        expect(find.text('Belt'), findsNothing);
        expectRowOrder(tester, ['Hat', 'Belt Two', 'Watch']);
        await confirm(tester);
        expect(result(), [21, 26, 23]);
      },
    );

    testWidgets(
      'swapping a single slot replaces it; a pick of another category while '
      'swapping goes to its own slot and leaves the row alone',
      (tester) async {
        final result = await open(
          tester,
          pool: [tee, jeans, sneakers, boots, jacket],
          initial: [sneakers, jeans, tee],
        );

        await tester.tap(find.text('Sneakers'));
        await tester.pumpAndSettle();
        expect(inPicker('Boots'), findsOneWidget);
        await pick(tester, 'Boots');
        expect(find.text('Sneakers'), findsNothing);

        await tester.tap(find.text('Boots'));
        await tester.pumpAndSettle();
        await tester.tap(inPicker('Outer'));
        await tester.pumpAndSettle();
        await pick(tester, 'Jacket');

        expect(find.text('Boots'), findsOneWidget);
        expectRowOrder(tester, ['Tee', 'Jacket', 'Jeans', 'Boots']);
        await confirm(tester);
        expect(result(), [1, 4, 5, 9]);
      },
    );

    testWidgets(
      'backing out of the picker changes nothing; backing out of the page '
      'pops null',
      (tester) async {
        final result = await open(
          tester,
          pool: [tee, jeans, sneakers],
          initial: [tee],
        );

        await tester.tap(find.text('Add Garment'));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(SelectGarmentPage))).pop();
        await tester.pumpAndSettle();
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Tee'), findsOneWidget);

        Navigator.of(tester.element(find.byType(OutfitEditPage))).pop();
        await tester.pumpAndSettle();
        expect(result(), isNull);
      },
    );

    testWidgets('removing every garment hides Confirm', (tester) async {
      await open(tester, pool: [tee, hat], initial: [tee, hat]);

      await remove(tester, 'Tee');
      expect(find.text('Confirm'), findsOneWidget);
      await remove(tester, 'Hat');
      expect(find.text('Confirm'), findsNothing);
    });
  });
}
