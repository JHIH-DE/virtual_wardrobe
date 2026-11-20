import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/wardrobe/create_outfit_selection.dart';

Garment _g(int id, GarmentCategory category, [String sub = '']) => Garment(
  id: id,
  name: 'G$id',
  category: category,
  subCategory: sub,
  uploadUrl: '',
  objectName: '',
);

List<int?> _ids(Iterable<Garment?> gs) => [for (final g in gs) g?.id];

void main() {
  final tee = _g(1, GarmentCategory.top, 'T-shirt');
  final polo = _g(2, GarmentCategory.top, 'Polo shirt');
  final cardi = _g(3, GarmentCategory.top, 'Cardigan');
  final hoodie = _g(4, GarmentCategory.top, 'Hoodie');
  final coat = _g(5, GarmentCategory.outer);
  final jeans = _g(6, GarmentCategory.bottom);
  final dress = _g(7, GarmentCategory.onePiece);
  final boots = _g(8, GarmentCategory.shoes);
  final chinos = _g(9, GarmentCategory.bottom);
  List<Garment> accessories(int n) => [
    for (var i = 0; i < n; i++)
      _g(20 + i, i.isEven ? GarmentCategory.accessory : GarmentCategory.socks),
  ];

  group('immutability', () {
    final cap = _g(30, GarmentCategory.accessory);

    /// Every way a selection comes to exist, each with tops and accessories.
    Map<String, OutfitSelection> variants() {
      final base = OutfitSelection.fromGarments([tee, ...accessories(2)]);
      return {
        'fromGarments': base,
        'constructor': OutfitSelection(tops: [tee], accessories: [cap]),
        'copyWith': base.copyWith(clearShoes: true),
        'withTop': base.withTop(cardi),
        'withTopAt': base.withTopAt(0, polo),
        'withSlot': base.withSlot(OutfitSlot.bottom, jeans),
        'withGarment': base.withGarment(cap)!,
        'withAccessoryAt': base.withAccessoryAt(0, cap),
        'withoutAccessoryAt': base.withoutAccessoryAt(0),
        'keepingOnly': base.keepingOnly({1, 20}),
      };
    }

    test('tops and accessories cannot be modified in place', () {
      for (final MapEntry(key: how, value: sel) in variants().entries) {
        expect(() => sel.tops.add(hoodie), throwsUnsupportedError, reason: how);
        expect(() => sel.tops[0] = hoodie, throwsUnsupportedError, reason: how);
        expect(
          () => sel.accessories.add(cap),
          throwsUnsupportedError,
          reason: how,
        );
        expect(
          () => sel.accessories[0] = null,
          throwsUnsupportedError,
          reason: how,
        );
      }
    });

    test('lists handed to the constructor are copied', () {
      final tops = [tee];
      final picked = <Garment?>[cap];
      final sel = OutfitSelection(tops: tops, accessories: picked);
      tops.add(cardi);
      picked
        ..clear()
        ..add(_g(31, GarmentCategory.accessory));
      expect(_ids(sel.tops), [1]);
      expect(_ids(sel.accessories), [30, null]);
    });

    test('the constructor applies the add-slot rule to what it is given', () {
      expect(_ids(OutfitSelection(accessories: const []).accessories), [null]);
      expect(
        _ids(
          OutfitSelection(
            accessories: [cap, null, accessories(1).first],
          ).accessories,
        ),
        [30, 20, null],
      );
      expect(_ids(OutfitSelection(accessories: accessories(4)).accessories), [
        20,
        21,
        22,
        23,
      ]);
    });

    test('every update returns a new selection and leaves the old one as it '
        'was', () {
      final base = OutfitSelection.fromGarments([tee, ...accessories(2)]);
      for (final MapEntry(key: how, value: next) in variants().entries) {
        if (how == 'fromGarments' || how == 'constructor') continue;
        expect(identical(next, base), isFalse, reason: how);
      }
      expect(_ids(base.tops), [1]);
      expect(_ids(base.accessories), [20, 21, null]);
    });
  });

  group('accessory slots', () {
    test('an empty selection has just the add-slot', () {
      expect(_ids(OutfitSelection().accessories), [null]);
    });

    test(
      'below the cap there is exactly one trailing add-slot; at it, none',
      () {
        for (var n = 0; n <= OutfitSelection.maxAccessories; n++) {
          final sel = OutfitSelection.fromGarments(accessories(n));
          expect(
            sel.accessories.where((a) => a == null),
            hasLength(n < OutfitSelection.maxAccessories ? 1 : 0),
          );
          expect(
            sel.accessories.last == null,
            n < OutfitSelection.maxAccessories,
          );
        }
      },
    );

    test('removing closes the gap and keeps the order', () {
      final sel = OutfitSelection.fromGarments(accessories(4));
      expect(_ids(sel.withoutAccessoryAt(1).accessories), [20, 22, 23, null]);
    });

    test('replacing keeps the place', () {
      final sel = OutfitSelection.fromGarments(accessories(2));
      final cap = _g(30, GarmentCategory.accessory);
      expect(_ids(sel.withAccessoryAt(0, cap).accessories), [30, 21, null]);
    });

    test('adding appends; the fourth fills the add-slot', () {
      var sel = OutfitSelection();
      for (final a in accessories(4)) {
        sel = sel.withGarment(a)!;
      }
      expect(_ids(sel.accessories), [20, 21, 22, 23]);
    });

    test('a fifth, or a garment already picked, does not go in', () {
      final full = OutfitSelection.fromGarments(accessories(4));
      expect(full.withGarment(_g(30, GarmentCategory.accessory)), isNull);
      final two = OutfitSelection.fromGarments(accessories(2));
      expect(two.withGarment(accessories(2).first), isNull);
    });

    test('accessories survive core edits', () {
      final sel = OutfitSelection.fromGarments([tee, ...accessories(2)]);
      expect(_ids(sel.withSlot(OutfitSlot.shoes, boots).accessories), [
        20,
        21,
        null,
      ]);
      expect(_ids(sel.withoutTopAt(0).accessories), [20, 21, null]);
      expect(_ids(sel.copyWith(clearOuter: true).accessories), [20, 21, null]);
    });
  });

  group('fromGarments', () {
    test('keeps the first two tops, the first of each single slot and the '
        'first four accessories, in the order given', () {
      final sel = OutfitSelection.fromGarments([
        ...accessories(5),
        boots,
        cardi,
        jeans,
        chinos,
        coat,
        tee,
        hoodie,
        dress,
      ]);
      expect(_ids(sel.tops), [3, 1]);
      expect(_ids(sel.garments), [3, 1, 5, 6, 7, 8]);
      expect(_ids(sel.accessories), [20, 21, 22, 23]);
    });
  });

  group('tops', () {
    test('an interchangeable top replaces the worn one in place', () {
      final sel = OutfitSelection.fromGarments([tee, cardi]);
      expect(_ids(sel.withTop(polo).tops), [2, 3]);
    });

    test(
      'another top is added while there is room, else replaces the last',
      () {
        final one = OutfitSelection.fromGarments([tee]);
        expect(_ids(one.withTop(cardi).tops), [1, 3]);
        final two = OutfitSelection.fromGarments([tee, cardi]);
        expect(_ids(two.withTop(hoodie).tops), [1, 4]);
      },
    );

    test('by index: replace or remove just that one', () {
      final sel = OutfitSelection.fromGarments([tee, cardi]);
      expect(_ids(sel.withTopAt(1, hoodie).tops), [1, 4]);
      expect(_ids(sel.withoutTopAt(0).tops), [3]);
    });
  });

  group('single slots', () {
    test('withGarment fills or replaces the slot for its category', () {
      var sel = OutfitSelection();
      for (final g in [coat, jeans, dress, boots]) {
        sel = sel.withGarment(g)!;
      }
      expect(_ids(sel.garments), [5, 6, 7, 8]);
      expect(sel.withGarment(chinos)!.bottom, chinos);
    });

    test('garmentIn / withSlot / withoutSlot reject the indexed top slot', () {
      final sel = OutfitSelection();
      expect(() => sel.garmentIn(OutfitSlot.top), throwsArgumentError);
      expect(() => sel.withSlot(OutfitSlot.top, tee), throwsArgumentError);
      expect(() => sel.withoutSlot(OutfitSlot.top), throwsArgumentError);
    });

    test('categoryFor maps each slot to its category', () {
      expect(
        {for (final s in OutfitSlot.values) s: OutfitSelection.categoryFor(s)},
        {
          OutfitSlot.top: GarmentCategory.top,
          OutfitSlot.outer: GarmentCategory.outer,
          OutfitSlot.bottom: GarmentCategory.bottom,
          OutfitSlot.onePiece: GarmentCategory.onePiece,
          OutfitSlot.shoes: GarmentCategory.shoes,
        },
      );
    });
  });

  group('hasRoomFor', () {
    test('a single slot only while empty; a top while under two and not '
        'interchangeable with a worn one; an accessory always', () {
      final sel = OutfitSelection.fromGarments([tee, jeans, ...accessories(4)]);
      expect(sel.hasRoomFor(chinos), isFalse);
      expect(sel.hasRoomFor(boots), isTrue);
      expect(sel.hasRoomFor(coat), isTrue);
      expect(sel.hasRoomFor(polo), isFalse);
      expect(sel.hasRoomFor(cardi), isTrue);
      expect(sel.withTop(cardi).hasRoomFor(hoodie), isFalse);
      expect(sel.hasRoomFor(_g(40, GarmentCategory.accessory)), isTrue);
    });
  });

  group('keepingOnly', () {
    test('keeps the listed garments where they were and clears the rest', () {
      final sel = OutfitSelection.fromGarments([
        tee,
        cardi,
        coat,
        jeans,
        boots,
        ...accessories(3),
      ]);
      final kept = sel.keepingOnly({3, 6, 21});
      expect(_ids(kept.tops), [3]);
      expect(kept.outer, isNull);
      expect(kept.bottom, jeans);
      expect(kept.shoes, isNull);
      expect(_ids(kept.accessories), [21, null]);
    });

    test('keeping nothing empties every slot', () {
      final sel = OutfitSelection.fromGarments([tee, boots, ...accessories(4)]);
      final none = sel.keepingOnly(const {});
      expect(none.garments, isEmpty);
      expect(_ids(none.accessories), [null]);
    });
  });
}
