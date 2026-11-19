import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/garment_sub_category.dart';

void main() {
  final catalog = SubCategoryCatalog.fromJson([
    {
      'category': 'Top',
      'options': [
        {'value': 'T-shirt', 'label': 'T 恤'},
        {'value': 'Button-up shirt', 'label': '襯衫'},
        {
          'value': 'Shirts',
          'label': '襯衫類',
          'styles': [
            {'value': 'Oxford shirt', 'label': '牛津襯衫'},
            {'value': 'Overshirt', 'label': '襯衫外搭'},
            // An odd style is skipped, not the whole option.
            'garbage',
          ],
        },
        {'value': 'Other', 'label': '其他', 'styles': []},
      ],
    },
    {
      'category': 'Outer',
      'options': [
        {'value': 'Button-up shirt', 'label': '襯衫'},
        {'value': 'Other'},
        // An odd label falls back instead of failing the list.
        {'value': 'Jacket', 'label': 42},
      ],
    },
    // A category this build doesn't know must not land on Top.
    {
      'category': 'Hat',
      'options': [
        {'value': 'Fedora', 'label': '紳士帽'},
      ],
    },
    'garbage',
  ]);

  test('parses the lists in order, per category', () {
    expect(catalog.optionsFor(GarmentCategory.top).map((o) => o.value), [
      'T-shirt',
      'Button-up shirt',
      'Shirts',
      'Other',
    ]);
    expect(catalog.optionsFor(GarmentCategory.shoes), isEmpty);
  });

  test('a missing or non-string label falls back to the value', () {
    final outer = catalog.optionsFor(GarmentCategory.outer);
    expect(outer[1].label, 'Other');
    expect(outer[2].label, 'Jacket');
  });

  test('allows checks the given category only', () {
    expect(catalog.allows(GarmentCategory.outer, 'Button-up shirt'), isTrue);
    expect(catalog.allows(GarmentCategory.outer, 'T-shirt'), isFalse);
  });

  test('labelFor maps a value; an unknown one stays as stored', () {
    expect(catalog.labelFor('T-shirt'), 'T 恤');
    expect(catalog.labelFor('Denim shirt'), 'Denim shirt');
    expect(catalog.labelFor('Fedora'), 'Fedora');
  });

  test('stylesFor lists the L3 under an L2; none when it has none', () {
    expect(
      catalog.stylesFor(GarmentCategory.top, 'Shirts').map((o) => o.value),
      ['Oxford shirt', 'Overshirt'],
    );
    expect(catalog.stylesFor(GarmentCategory.top, 'Other'), isEmpty);
    expect(catalog.stylesFor(GarmentCategory.top, 'T-shirt'), isEmpty);
    // Only the given category's list.
    expect(catalog.stylesFor(GarmentCategory.outer, 'Shirts'), isEmpty);
  });

  test('labelFor also maps L3 styles', () {
    expect(catalog.labelFor('Overshirt'), '襯衫外搭');
  });
}
