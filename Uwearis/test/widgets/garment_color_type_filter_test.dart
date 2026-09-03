import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/common/buttons/garment_color_type_filter.dart';

Garment _g({String? color, String sub = ''}) => Garment(
  name: 'x',
  category: GarmentCategory.top,
  subCategory: sub,
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
  color: color,
);

void main() {
  final pool = [
    _g(color: 'Blue', sub: 'Shirt'),
    _g(color: 'Red', sub: 'T-Shirt'),
    _g(color: 'Blue', sub: 'Sweater'),
    _g(sub: 'Tank'),
  ];

  test('starts inactive with everything selected', () {
    final f = GarmentColorTypeFilter();
    expect(f.isActive, isFalse);
    expect(f.apply(pool).length, pool.length);
  });

  test('available lists are sorted and prefixed with "All"', () {
    final f = GarmentColorTypeFilter();
    expect(f.availableColors(pool), ['All', 'Blue', 'Red']);
    expect(f.availableTypes(pool), ['All', 'Shirt', 'Sweater', 'T-Shirt', 'Tank']);
  });

  test('filtering by colour is case-insensitive', () {
    final f = GarmentColorTypeFilter()..colors = {'blue'};
    expect(f.isActive, isTrue);
    expect(f.apply(pool).length, 2);
  });

  test('colour and type filters combine (AND)', () {
    final f = GarmentColorTypeFilter()
      ..colors = {'Blue'}
      ..types = {'Shirt'};
    expect(f.apply(pool).length, 1);
  });

  test('reset returns to the all-selected state', () {
    final f = GarmentColorTypeFilter()..colors = {'Blue'};
    f.reset();
    expect(f.isActive, isFalse);
    expect(f.apply(pool).length, pool.length);
  });
}
