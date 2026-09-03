import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';

void main() {
  group('GarmentCategoryX.fromApiValue', () {
    test('parses a known label, case-insensitively', () {
      expect(GarmentCategoryX.fromApiValue('Bottom'), GarmentCategory.bottom);
      expect(GarmentCategoryX.fromApiValue('bottom'), GarmentCategory.bottom);
      expect(GarmentCategoryX.fromApiValue('SHOES'), GarmentCategory.shoes);
    });

    test('falls back to top for null or an unrecognized value', () {
      expect(GarmentCategoryX.fromApiValue(null), GarmentCategory.top);
      expect(GarmentCategoryX.fromApiValue('not-a-category'), GarmentCategory.top);
    });
  });

  group('GarmentFitX.fromApiValue', () {
    test('parses by enum name or label, case-insensitively', () {
      expect(GarmentFitX.fromApiValue('slim'), GarmentFit.slim);
      expect(GarmentFitX.fromApiValue('Relaxed'), GarmentFit.relaxed);
      expect(GarmentFitX.fromApiValue('OVERSIZED'), GarmentFit.oversized);
    });

    test('returns null for null or an unrecognized value', () {
      expect(GarmentFitX.fromApiValue(null), isNull);
      expect(GarmentFitX.fromApiValue('baggy'), isNull);
    });
  });

  group('Garment.fromJson', () {
    test('parses a typical fully-populated payload', () {
      final garment = Garment.fromJson({
        'id': 7,
        'garment_id': 7,
        'name': 'Navy Blazer',
        'brand': 'Uniqlo',
        'color': 'Navy',
        'fit': 'Regular',
        'price': 89.99,
        'thickness': 2,
        'formality': 4,
        'purchase_date': '2025-03-14',
        'category': 'Outer',
        'sub_category': 'Blazer',
        'upload_url': 'https://example.com/upload',
        'object_name': 'garments/7.jpg',
        'image_url': 'https://example.com/7.jpg',
        'metadata': {'note': 'dry clean only'},
        'is_favorite': true,
      });

      expect(garment.id, 7);
      expect(garment.garmentId, 7);
      expect(garment.name, 'Navy Blazer');
      expect(garment.brand, 'Uniqlo');
      expect(garment.color, 'Navy');
      expect(garment.fit, 'Regular');
      expect(garment.price, 89.99);
      expect(garment.thickness, 2);
      expect(garment.formality, 4);
      expect(garment.purchaseDate, DateTime.parse('2025-03-14'));
      expect(garment.category, GarmentCategory.outer);
      expect(garment.subCategory, 'Blazer');
      expect(garment.uploadUrl, 'https://example.com/upload');
      expect(garment.objectName, 'garments/7.jpg');
      expect(garment.imageUrl, 'https://example.com/7.jpg');
      expect(garment.metadata, {'note': 'dry clean only'});
      expect(garment.isFavorite, isTrue);
    });

    test('defaults missing optional fields', () {
      final garment = Garment.fromJson({});

      expect(garment.id, isNull);
      expect(garment.garmentId, isNull);
      expect(garment.name, '');
      expect(garment.brand, isNull);
      expect(garment.color, isNull);
      expect(garment.fit, isNull);
      expect(garment.price, isNull);
      expect(garment.thickness, 0);
      expect(garment.formality, 0);
      expect(garment.purchaseDate, isNull);
      expect(garment.category, GarmentCategory.top);
      expect(garment.subCategory, '');
      expect(garment.uploadUrl, '');
      expect(garment.objectName, '');
      expect(garment.imageUrl, '');
      expect(garment.metadata, isNull);
      expect(garment.isFavorite, isFalse);
    });

    test('parses price/thickness/formality given as strings, same as numbers', () {
      final garment = Garment.fromJson({
        'price': '49.5',
        'thickness': '1',
        'formality': '4',
      });

      expect(garment.price, 49.5);
      expect(garment.thickness, 1);
      expect(garment.formality, 4);
    });

    test('rounds a non-integer thickness/formality to the nearest int', () {
      final garment = Garment.fromJson({'thickness': 2.6, 'formality': '3.2'});
      expect(garment.thickness, 3);
      expect(garment.formality, 3);
    });

    test('parses id/garment_id sent as an integer-valued double', () {
      final garment = Garment.fromJson({'id': 5.0, 'garment_id': 5.0});
      expect(garment.id, 5);
      expect(garment.garmentId, 5);
    });

    test('leaves id/garment_id null when the key is absent or null', () {
      final garment = Garment.fromJson({'id': null});
      expect(garment.id, isNull);
      expect(garment.garmentId, isNull);
    });

    // id/garment_id are always JSON numbers on this endpoint — unlike
    // price/thickness/formality they have never accepted a numeric string, so
    // a string (or any non-number) still throws rather than being coerced.
    test('throws on a non-numeric id/garment_id, contract unchanged', () {
      expect(() => Garment.fromJson({'id': 'abc'}), throwsA(isA<TypeError>()));
      expect(() => Garment.fromJson({'id': '7'}), throwsA(isA<TypeError>()));
      expect(
        () => Garment.fromJson({'garment_id': true}),
        throwsA(isA<TypeError>()),
      );
    });

    // A fractional / non-finite id must never be truncated to a whole number
    // — that would silently point the app at a different garment row.
    test('throws on a fractional, NaN or Infinity id/garment_id', () {
      expect(
        () => Garment.fromJson({'id': 5.5}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Garment.fromJson({'id': double.nan}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Garment.fromJson({'garment_id': double.infinity}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Garment.fromJson({'garment_id': double.negativeInfinity}),
        throwsA(isA<FormatException>()),
      );
    });

    test('treats an unparseable purchase_date as null rather than throwing', () {
      final garment = Garment.fromJson({'purchase_date': 'not-a-date'});
      expect(garment.purchaseDate, isNull);
    });
  });

  group('Garment.fromTripItemJson', () {
    test('takes both id and garmentId from garment_id', () {
      final garment = Garment.fromTripItemJson({
        'garment_id': 42,
        'name': 'White Sneakers',
        'color': 'White',
        'category': 'Shoes',
        'image_url': 'https://example.com/42.jpg',
      });

      expect(garment.id, 42);
      expect(garment.garmentId, 42);
      expect(garment.name, 'White Sneakers');
      expect(garment.color, 'White');
      expect(garment.category, GarmentCategory.shoes);
      expect(garment.imageUrl, 'https://example.com/42.jpg');
      // Fields the trip item response doesn't carry stay at their defaults.
      expect(garment.subCategory, '');
      expect(garment.uploadUrl, '');
      expect(garment.objectName, '');
      expect(garment.brand, isNull);
    });

    test('leaves color null when the trip item omits it', () {
      final garment = Garment.fromTripItemJson({'garment_id': 1});
      expect(garment.color, isNull);
    });

    test('parses a garment_id sent as an integer-valued double', () {
      final garment = Garment.fromTripItemJson({'garment_id': 42.0});
      expect(garment.id, 42);
      expect(garment.garmentId, 42);
    });

    test('leaves id/garmentId null when garment_id is absent', () {
      final garment = Garment.fromTripItemJson({'image_url': 'x'});
      expect(garment.id, isNull);
      expect(garment.garmentId, isNull);
    });

    test('throws on a non-numeric garment_id', () {
      expect(
        () => Garment.fromTripItemJson({'garment_id': 'abc'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws on a fractional, NaN or Infinity garment_id', () {
      expect(
        () => Garment.fromTripItemJson({'garment_id': 5.5}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Garment.fromTripItemJson({'garment_id': double.nan}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Garment.fromTripItemJson({'garment_id': double.infinity}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Garment.copyWith', () {
    Garment build() => Garment.fromJson({
      'id': 1,
      'garment_id': 1,
      'name': 'Base Tee',
      'category': 'Top',
      'brand': 'Uniqlo',
      'color': 'White',
      'fit': 'Regular',
      'price': 20.0,
      'purchase_date': '2025-01-01',
      'metadata': {'a': 1},
    });

    test('overrides only the given fields, keeps the rest', () {
      final updated = build().copyWith(name: 'Renamed Tee', price: 25.0);
      expect(updated.name, 'Renamed Tee');
      expect(updated.price, 25.0);
      expect(updated.brand, 'Uniqlo');
    });

    test('clear flags null out their field even though the plain param is omitted', () {
      final original = build();
      final cleared = original.copyWith(
        clearBrand: true,
        clearColor: true,
        clearFit: true,
        clearPrice: true,
        clearPurchaseDate: true,
        clearMetadata: true,
      );

      expect(cleared.brand, isNull);
      expect(cleared.color, isNull);
      expect(cleared.fit, isNull);
      expect(cleared.price, isNull);
      expect(cleared.purchaseDate, isNull);
      expect(cleared.metadata, isNull);
      // Untouched fields survive.
      expect(cleared.name, original.name);
    });

    test('clearId/clearGarmentId null out independently of each other', () {
      final cleared = build().copyWith(clearId: true);
      expect(cleared.id, isNull);
      expect(cleared.garmentId, 1);
    });
  });

  group('Garment.toJson', () {
    test('round-trips the fields it carries, serializing category/date', () {
      final garment = Garment.fromJson({
        'id': 7,
        'garment_id': 7,
        'name': 'Navy Blazer',
        'category': 'Outer',
        'sub_category': 'Blazer',
        'purchase_date': '2025-03-14T00:00:00.000',
        'upload_url': 'https://example.com/upload',
        'object_name': 'garments/7.jpg',
      });

      final json = garment.toJson();
      expect(json['id'], 7);
      expect(json['garment_id'], 7);
      expect(json['name'], 'Navy Blazer');
      expect(json['category'], 'Outer');
      expect(json['sub_category'], 'Blazer');
      expect(json['purchase_date'], '2025-03-14');
      expect(json['upload_url'], 'https://example.com/upload');
      expect(json['object_name'], 'garments/7.jpg');
    });

    test('serializes a null purchase_date as null, not an exception', () {
      final garment = Garment.fromJson({'name': 'No Date'});
      expect(garment.toJson()['purchase_date'], isNull);
    });

    // The backend `purchase_date` is a Pydantic `date` — it rejects a
    // datetime string with a non-zero time component. A picked date can carry
    // a time (or a future default might), so toJson must always emit
    // `yyyy-MM-dd`, matching GarmentService.completeUpload's own serialization.
    test('serializes purchase_date as date-only even when the DateTime has a time', () {
      final garment = Garment(
        name: 'Timed',
        category: GarmentCategory.top,
        subCategory: '',
        uploadUrl: '',
        objectName: '',
        purchaseDate: DateTime(2025, 3, 14, 9, 30, 45),
      );
      expect(garment.purchaseDateApiValue, '2025-03-14');
      expect(garment.toJson()['purchase_date'], '2025-03-14');
    });
  });
}
