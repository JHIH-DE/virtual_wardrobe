import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/versatility.dart';

void main() {
  group('Versatility.fromJson', () {
    test('parses score and a full breakdown', () {
      final v = Versatility.fromJson({
        'score': 74,
        'breakdown': [
          {
            'category': 'Bottom',
            'compatible_count': 5,
            'compatible_garment_ids': [1, 2.0, 3],
          },
          {'category': 'Shoes', 'compatible_count': 0},
        ],
      });

      expect(v.score, 74);
      expect(v.breakdown, hasLength(2));
      final bottom = v.breakdown.first;
      expect(bottom.category, GarmentCategory.bottom);
      expect(bottom.compatibleCount, 5);
      expect(bottom.compatibleGarmentIds, [1, 2, 3]);
    });

    test('tolerates a missing score and missing breakdown', () {
      final v = Versatility.fromJson({});
      expect(v.score, isNull);
      expect(v.breakdown, isEmpty);
    });

    test('a breakdown row with no ids defaults to an empty list', () {
      final v = Versatility.fromJson({
        'breakdown': [
          {'category': 'Top', 'compatible_count': 2},
        ],
      });
      expect(v.breakdown.single.compatibleGarmentIds, isEmpty);
    });
  });
}
