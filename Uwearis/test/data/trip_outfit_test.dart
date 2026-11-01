import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/trip_outfit.dart';

Garment _g(int id, GarmentCategory category, {bool deleted = false}) => Garment(
  id: id,
  garmentId: id,
  name: '',
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
  isDeleted: deleted,
);

void main() {
  group('TripOutfitCollection.fromJson', () {
    test('parses outfits, suitcase, candidates and the suggested range', () {
      final c = TripOutfitCollection.fromJson({
        'total_days': 5,
        'suggested_outfit_count': {'min': 4, 'max': 6},
        'suitcase_items': [
          {'garment_id': 1, 'category': 'Top'},
          {'garment_id': 2.0, 'category': 'Bottom'},
        ],
        'outfits': [
          {
            'id': 9,
            'source': 'saved_outfit',
            'source_outfit_id': 55,
            'is_pinned': false,
            'is_replaceable': false,
            'image_outfit_id': 55,
            'result_image_url': 'https://x/y.jpg',
            'reasoning': ['Warm', 3],
            'garments': [
              {'garment_id': 1, 'category': 'Top'},
              {'garment_id': 3, 'category': 'Shoes', 'is_deleted': true},
            ],
          },
          {'id': 10, 'source': 'suggested', 'is_replaceable': true},
        ],
      });

      expect(c.totalDays, 5);
      expect((c.suggestedMin, c.suggestedMax), (4, 6));
      expect(c.suitcaseIds, {1, 2});
      expect(c.addedSourceOutfitIds, {55});
      expect(c.savedOutfitCount, 1);
      expect(c.replaceableOutfits.map((o) => o.id), [10]);

      final saved = c.outfits.first;
      expect(saved.source, TripOutfitSource.savedOutfit);
      expect(saved.outfitId, isNull);
      expect(saved.hasImage, isTrue);
      expect(saved.reasoning, ['Warm']);
      // Not packed + deleted from the closet both count as missing.
      expect(saved.missingGarments(c.suitcaseIds).map((g) => g.id), [3]);
      expect(saved.garments.last.isDeleted, isTrue);
    });

    test('tolerates a missing or malformed body', () {
      final c = TripOutfitCollection.fromJson({});
      expect(c.outfits, isEmpty);
      expect(c.suitcase, isEmpty);
      expect((c.suggestedMin, c.suggestedMax), (0, 0));
    });

    test('an unknown source reads as a suggestion', () {
      expect(
        TripOutfitSourceApi.fromApiValue('something_new'),
        TripOutfitSource.suggested,
      );
      for (final s in TripOutfitSource.values) {
        expect(TripOutfitSourceApi.fromApiValue(s.apiValue), s);
      }
    });
  });

  test('TripOutfitGenerateResult reads each source\'s count and the AI '
      'status next to the collection', () {
    final r = TripOutfitGenerateResult.fromJson({
      'outfits': [
        {'id': 1, 'source': 'suggested'},
      ],
      'refresh_batch_size': 1,
      'saved_added_count': 4,
      'ai_added_count': 2,
      'replaced_count': 1,
      'ai_status': 'rate_limited',
    });
    expect((r.savedAddedCount, r.aiAddedCount, r.replacedCount), (4, 2, 1));
    expect(r.aiStatus, TripOutfitAiStatus.rateLimited);
    expect(r.collection.outfits, hasLength(1));
    expect(r.collection.refreshBatchSize, 1);
  });

  test('an unknown or missing AI status reads as no new outfits', () {
    expect(
      TripOutfitGenerateResult.fromJson({}).aiStatus,
      TripOutfitAiStatus.noNew,
    );
    expect(
      TripOutfitAiStatusApi.fromApiValue('something_new'),
      TripOutfitAiStatus.noNew,
    );
  });

  group('isViableSuitcase', () {
    test('needs top + bottom or a one-piece, plus shoes', () {
      expect(
        isViableSuitcase([
          _g(1, GarmentCategory.top),
          _g(2, GarmentCategory.bottom),
          _g(3, GarmentCategory.shoes),
        ]),
        isTrue,
      );
      expect(
        isViableSuitcase([
          _g(1, GarmentCategory.onePiece),
          _g(3, GarmentCategory.shoes),
        ]),
        isTrue,
      );
      expect(
        isViableSuitcase([
          _g(1, GarmentCategory.top),
          _g(2, GarmentCategory.bottom),
        ]),
        isFalse,
      );
    });

    test('a garment deleted from the closet does not count', () {
      expect(
        isViableSuitcase([
          _g(1, GarmentCategory.onePiece),
          _g(3, GarmentCategory.shoes, deleted: true),
        ]),
        isFalse,
      );
    });
  });
}
