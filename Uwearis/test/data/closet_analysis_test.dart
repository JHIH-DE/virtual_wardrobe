import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/closet_analysis.dart';
import 'package:uwearis/data/garment.dart';

void main() {
  group('ClosetAnalysis.fromJson', () {
    test('parses versatility, outfit ideas, and similar garments', () {
      final analysis = ClosetAnalysis.fromJson({
        'versatility': {'level': 8, 'label': 'Versatile'},
        'outfit_ideas': [
          {
            'title': 'Rugged Workwear Layering',
            'garments': [
              {
                'garment_id': 203,
                'category': 'Outer',
                'name': 'Plaid Flannel Shirt',
                'image_url': 'https://storage.googleapis.com/a.jpg',
                'is_target': true,
              },
              {
                'garment_id': 109,
                'category': 'Bottom',
                'name': 'Wide Tapered Denim Pants',
                'image_url': 'https://storage.googleapis.com/b.jpg',
                'is_target': false,
              },
            ],
          },
        ],
        'similar_garments': [
          {
            'garment_id': 106,
            'name': 'Plaid Flannel Shirt',
            'category': 'Top',
            'image_url': 'https://storage.googleapis.com/c.jpg',
          },
        ],
      });

      expect(analysis.versatility.level, 8);
      expect(analysis.versatility.label, VersatilityLabel.versatile);

      expect(analysis.outfitIdeas, hasLength(1));
      final idea = analysis.outfitIdeas.single;
      expect(idea.title, 'Rugged Workwear Layering');
      expect(idea.garments, hasLength(2));
      expect(idea.garments.first.isTarget, isTrue);
      expect(idea.garments.first.category, GarmentCategory.outer);
      expect(idea.garments.last.isTarget, isFalse);

      expect(analysis.similarGarments, hasLength(1));
      expect(analysis.similarGarments.single.garmentId, 106);
      expect(analysis.similarGarments.single.isTarget, isFalse);
    });

    test('a Closet-with-only-the-target response is a normal success', () {
      // garments-api.md §8: when the closet has nothing but the target,
      // the backend still answers 200 with level 1 / Very Limited and
      // empty arrays — not an error.
      final analysis = ClosetAnalysis.fromJson({
        'versatility': {'level': 1, 'label': 'Very Limited'},
        'outfit_ideas': [],
        'similar_garments': [],
      });

      expect(analysis.versatility.level, 1);
      expect(analysis.versatility.label, VersatilityLabel.veryLimited);
      expect(analysis.outfitIdeas, isEmpty);
      expect(analysis.similarGarments, isEmpty);
    });

    test('tolerates a missing versatility object and missing lists', () {
      final analysis = ClosetAnalysis.fromJson({});
      expect(analysis.versatility.level, 1);
      expect(analysis.versatility.label, VersatilityLabel.moderate);
      expect(analysis.outfitIdeas, isEmpty);
      expect(analysis.similarGarments, isEmpty);
    });

    test('an unrecognized label falls back to Moderate', () {
      final analysis = ClosetAnalysis.fromJson({
        'versatility': {'level': 5, 'label': 'Something New'},
      });
      expect(analysis.versatility.label, VersatilityLabel.moderate);
    });
  });

  group('ClosetAnalysis.toJson round-trip', () {
    // GarmentService persists a closet-analysis result to local storage by
    // round-tripping it through toJson/fromJson — this is what that cache
    // relies on staying lossless.
    test('fromJson(toJson(x)) reproduces every field', () {
      final original = ClosetAnalysis.fromJson({
        'versatility': {'level': 8, 'label': 'Versatile'},
        'outfit_ideas': [
          {
            'title': 'Rugged Workwear Layering',
            'garments': [
              {
                'garment_id': 203,
                'category': 'Outer',
                'name': 'Plaid Flannel Shirt',
                'image_url': 'https://storage.googleapis.com/a.jpg',
                'is_target': true,
              },
            ],
          },
        ],
        'similar_garments': [
          {
            'garment_id': 106,
            'name': 'Plaid Flannel Shirt',
            'category': 'Top',
            'image_url': 'https://storage.googleapis.com/c.jpg',
          },
        ],
      });

      final roundTripped = ClosetAnalysis.fromJson(original.toJson());

      expect(roundTripped.versatility.level, original.versatility.level);
      expect(roundTripped.versatility.label, original.versatility.label);
      expect(roundTripped.outfitIdeas, hasLength(1));
      expect(roundTripped.outfitIdeas.single.title, 'Rugged Workwear Layering');
      expect(roundTripped.outfitIdeas.single.garments.single.garmentId, 203);
      expect(roundTripped.outfitIdeas.single.garments.single.isTarget, isTrue);
      expect(roundTripped.similarGarments.single.garmentId, 106);
      expect(roundTripped.similarGarments.single.category, GarmentCategory.top);
    });

    test('an empty analysis round-trips to empty lists, not null', () {
      final original = ClosetAnalysis.fromJson({
        'versatility': {'level': 1, 'label': 'Very Limited'},
        'outfit_ideas': [],
        'similar_garments': [],
      });

      final roundTripped = ClosetAnalysis.fromJson(original.toJson());

      expect(roundTripped.outfitIdeas, isEmpty);
      expect(roundTripped.similarGarments, isEmpty);
    });
  });
}
