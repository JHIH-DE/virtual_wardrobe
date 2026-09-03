import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/packing_analysis.dart';

void main() {
  group('PackingCategory.fromJson', () {
    test('parses a fully-populated row', () {
      final c = PackingCategory.fromJson({
        'category': 'Top',
        'recommended_quantity': 3,
        'suggested_garment_ids': [7, 8, 9],
        'reasoning': 'Layering pieces for the cold.',
      });
      expect(c.category, GarmentCategory.top);
      expect(c.recommendedQuantity, 3);
      expect(c.suggestedGarmentIds, {7, 8, 9});
      expect(c.reasoning, 'Layering pieces for the cold.');
    });

    test('joins a reasoning list into newline-separated text', () {
      final c = PackingCategory.fromJson({
        'category': 'Bottom',
        'reasoning': ['One.', 'Two.'],
      });
      expect(c.reasoning, 'One.\nTwo.');
    });

    test('defaults a missing/blank row without throwing', () {
      final c = PackingCategory.fromJson({'category': 'Shoes'});
      expect(c.recommendedQuantity, 0);
      expect(c.suggestedGarmentIds, isEmpty);
      expect(c.reasoning, '');
    });

    test('accepts float garment ids', () {
      final c = PackingCategory.fromJson({
        'category': 'Top',
        'suggested_garment_ids': [7.0, 8],
      });
      expect(c.suggestedGarmentIds, {7, 8});
    });
  });

  group('PackingAnalysis.fromJson', () {
    test('recommendedTotal sums every category', () {
      final a = PackingAnalysis.fromJson({
        'overall_advice': 'Travel light.',
        'categories': [
          {'category': 'Top', 'recommended_quantity': 3},
          {'category': 'Bottom', 'recommended_quantity': 2},
          {'category': 'Shoes', 'recommended_quantity': 1},
        ],
      });
      expect(a.overallAdvice, 'Travel light.');
      expect(a.recommendedTotal, 6);
      expect(a.forCategory(GarmentCategory.bottom)!.recommendedQuantity, 2);
      expect(a.forCategory(GarmentCategory.accessory), isNull);
    });

    test('an empty / missing categories list gives a 0 total, no crash', () {
      final a = PackingAnalysis.fromJson({'overall_advice': null});
      expect(a.categories, isEmpty);
      expect(a.recommendedTotal, 0);
    });
  });
}
