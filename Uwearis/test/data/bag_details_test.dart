import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/bag_details.dart';
import 'package:uwearis/data/garment.dart';

const _sacocheJson = <String, dynamic>{
  'bag_type': 'sacoche',
  'body_width_cm': 25,
  'strap_width_class': 'thin',
};

void main() {
  group('BagDetails', () {
    test('round-trips the backend shape', () {
      final d = BagDetails.fromJson(_sacocheJson);
      expect(d.bagType, BagType.sacoche);
      expect(d.bodyWidthCm, 25.0);
      expect(d.strapWidthClass, StrapWidthClass.thin);
      expect(d.toJson(), {..._sacocheJson, 'body_width_cm': 25.0});
    });

    test('snake_case values map both ways', () {
      final d = BagDetails.fromJson({
        'bag_type': 'crossbody_bag',
        'strap_width_class': 'extra_thin',
      });
      expect(d.bagType, BagType.crossbodyBag);
      expect(d.strapWidthClass, StrapWidthClass.extraThin);
      expect(d.toJson()['bag_type'], 'crossbody_bag');
      expect(d.toJson()['strap_width_class'], 'extra_thin');
    });

    test('unknown values parse as unset; removed fields are dropped', () {
      final d = BagDetails.fromJson({
        'bag_type': 'duffel',
        'body_width_cm': '25',
        // Fields an older backend may still send.
        'strap_type': 'webbing',
        'has_top_handle': false,
        'supported_carry_styles': ['shoulder'],
        'default_carry_style': 'shoulder',
      });
      expect(d.bagType, isNull);
      expect(d.bodyWidthCm, isNull);
      expect(d.toJson().keys, [
        'bag_type',
        'body_width_cm',
        'strap_width_class',
      ]);
    });

    test('the width clears explicitly and survives other edits', () {
      final d = BagDetails.fromJson(_sacocheJson);
      expect(d.copyWith(bagType: BagType.tote).bodyWidthCm, 25.0);
      expect(d.copyWith(clearBodyWidthCm: true).bodyWidthCm, isNull);
    });

    test('value equality', () {
      final a = BagDetails.fromJson(_sacocheJson);
      final b = BagDetails.fromJson(_sacocheJson);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const BagDetails(bagType: BagType.sacoche)));
    });
  });

  test('isBagGarment mirrors the backend keywords', () {
    for (final sub in ['Bag', 'Tote bag', 'Backpack', 'Sacoche', '斜背包']) {
      expect(isBagGarment(GarmentCategory.accessory, sub), isTrue, reason: sub);
    }
    for (final sub in ['Cap', 'Belt', 'Bagel hat', '']) {
      expect(
        isBagGarment(GarmentCategory.accessory, sub),
        isFalse,
        reason: sub,
      );
    }
    expect(isBagGarment(GarmentCategory.top, 'Bag'), isFalse);
  });

  group('Garment', () {
    test('parses bag_details', () {
      final g = Garment.fromJson({
        'id': 288,
        'category': 'Accessory',
        'sub_category': 'Bag',
        'bag_details': _sacocheJson,
      });
      expect(g.isBag, isTrue);
      expect(g.bagDetails?.bagType, BagType.sacoche);
      expect(Garment.fromJson(g.toJson()).bagDetails, g.bagDetails);
    });

    test('legacy rows have none', () {
      final g = Garment.fromJson({'id': 1, 'category': 'Accessory'});
      expect(g.bagDetails, isNull);
    });

    test('copyWith keeps and clears bag details', () {
      final g = Garment.fromJson({
        'id': 1,
        'category': 'Accessory',
        'sub_category': 'Bag',
        'bag_details': _sacocheJson,
      });
      expect(g.copyWith(name: 'x').bagDetails, g.bagDetails);
      expect(g.copyWith(clearBagDetails: true).bagDetails, isNull);
    });
  });
}
