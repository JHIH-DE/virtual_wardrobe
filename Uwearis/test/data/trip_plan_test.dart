import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/trip_plan.dart';

void main() {
  group('parseSuitcaseItemIds', () {
    test('reads {garment_id} objects', () {
      expect(
        parseSuitcaseItemIds([
          {'garment_id': 1},
          {'garment_id': 2},
        ]),
        {1, 2},
      );
    });

    test('reads bare numbers, including floats', () {
      expect(parseSuitcaseItemIds([3, 4.0]), {3, 4});
    });

    test('anything else is an empty set', () {
      expect(parseSuitcaseItemIds(null), isEmpty);
      expect(parseSuitcaseItemIds('nope'), isEmpty);
    });
  });

  group('TripPlan.fromPlanResponse', () {
    test('parses each day\'s primary (lowest order_index) option', () {
      final plan = TripPlan.fromPlanResponse({
        'suitcase_items': [
          {'garment_id': 10},
        ],
        'days': [
          {
            'date': '2026-10-01',
            'temperature_max_c': 20,
            'temperature_min_c': 12,
            'options': [
              {
                'id': 7,
                'order_index': 1,
                'items': [
                  {'garment_id': 99, 'name': 'B', 'category': 'Top'},
                ],
              },
              {
                'id': 5,
                'order_index': 0,
                'outfit_id': 42,
                'result_image_url': 'https://img/5.png',
                'items': [
                  {'garment_id': 98, 'name': 'A', 'category': 'Bottom'},
                ],
              },
            ],
          },
        ],
      });

      expect(plan.suitcaseIds, {10});
      expect(plan.days, hasLength(1));
      final day = plan.days.single;
      expect(day.date, DateTime(2026, 10, 1));
      expect(day.optionId, 5);
      expect(day.outfitId, 42);
      expect(day.everHadOutfit, isTrue);
      expect(day.resultImageUrl, 'https://img/5.png');
      expect(day.temperatureMaxC, 20);
      expect(day.garments.single.category, GarmentCategory.bottom);
    });

    test('a day with no options is empty but keeps its date/temperature', () {
      final plan = TripPlan.fromPlanResponse({
        'days': [
          {'date': '2026-10-02', 'temperature_min_c': 8, 'options': []},
        ],
      });
      final day = plan.days.single;
      expect(day.optionId, isNull);
      expect(day.everHadOutfit, isFalse);
      expect(day.garments, isEmpty);
      expect(day.date, DateTime(2026, 10, 2));
      expect(day.temperatureMinC, 8);
    });

    test('missing days gives an empty plan, no crash', () {
      expect(TripPlan.fromPlanResponse({}).days, isEmpty);
    });
  });

  group('TripPlan.fromRenderedResponse', () {
    final closet = [
      const Garment(
        id: 1,
        name: 'Shirt',
        category: GarmentCategory.top,
        subCategory: '',
        uploadUrl: '',
        objectName: '',
      ),
      const Garment(
        id: 2,
        name: 'Jeans',
        category: GarmentCategory.bottom,
        subCategory: '',
        uploadUrl: '',
        objectName: '',
      ),
    ];

    test('resolves garment_ids against the closet, prefers option_type primary',
        () {
      final plan = TripPlan.fromRenderedResponse({
        'suitcase_items': [
          {'garment_id': 1},
        ],
        'days': [
          {
            'date': '2026-10-01',
            'outfits': [
              {'option_type': 'alternative', 'garment_ids': [2]},
              {
                'option_type': 'primary',
                'trip_option_id': 3,
                'outfit_id': 88,
                'result_image_url': 'https://img/88.png',
                'garment_ids': [1, 999],
              },
            ],
          },
        ],
      }, closet);

      final day = plan.days.single;
      expect(day.optionId, 3);
      expect(day.outfitId, 88);
      expect(day.everHadOutfit, isTrue);
      // 999 isn't in the closet, so it drops out.
      expect(day.garments.map((g) => g.id), [1]);
      expect(plan.suitcaseIds, {1});
    });

    test('a day with no outfits is empty', () {
      final plan = TripPlan.fromRenderedResponse({
        'days': [
          {'date': '2026-10-03', 'outfits': []},
        ],
      }, closet);
      expect(plan.days.single.optionId, isNull);
      expect(plan.days.single.everHadOutfit, isFalse);
    });
  });
}
