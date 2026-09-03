import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/outfit.dart';

void main() {
  group('Outfit.fromJson', () {
    test('parses a typical fully-populated payload', () {
      final outfit = Outfit.fromJson({
        'outfit_id': 101,
        'group_id': 12,
        'group_type': 'general',
        'status': 'completed',
        'name': 'Relaxed City Layers',
        'garment_ids': [12, 55, 88],
        'result_image_url': 'https://example.com/outfit.jpg',
        'season': ['autumn'],
        'style': ['streetwear', 'smart_casual'],
        'error_message': null,
        'background_id': 3,
        'is_favorite': true,
      });

      expect(outfit.id, 101);
      expect(outfit.groupId, 12);
      expect(outfit.groupType, OutfitGroupType.general);
      expect(outfit.status, 'completed');
      expect(outfit.name, 'Relaxed City Layers');
      expect(outfit.garmentIds, [12, 55, 88]);
      expect(outfit.imageUrl, 'https://example.com/outfit.jpg');
      expect(outfit.seasons, ['autumn']);
      expect(outfit.style, ['streetwear', 'smart_casual']);
      expect(outfit.errorMessage, isNull);
      expect(outfit.backgroundId, 3);
      expect(outfit.isFavorite, isTrue);
    });

    test('defaults missing optional fields', () {
      final outfit = Outfit.fromJson({'outfit_id': 1});

      expect(outfit.groupId, 0);
      expect(outfit.groupType, OutfitGroupType.general);
      expect(outfit.status, 'completed');
      expect(outfit.name, isNull);
      expect(outfit.garmentIds, isEmpty);
      expect(outfit.imageUrl, '');
      expect(outfit.seasons, isEmpty);
      expect(outfit.style, isEmpty);
      expect(outfit.backgroundId, isNull);
      expect(outfit.isFavorite, isFalse);
      expect(outfit.reasoning, isNull);
      // Attached separately by OutfitService from the group wrapper, never
      // present on a bare OutfitOut payload.
      expect(outfit.coverOutfitId, isNull);
      expect(outfit.groupName, isNull);
    });

    test('parses ids given as strings, same as ints', () {
      final outfit = Outfit.fromJson({
        'outfit_id': '101',
        'group_id': '12',
        'garment_ids': ['12', '55', 88],
      });

      expect(outfit.id, 101);
      expect(outfit.groupId, 12);
      expect(outfit.garmentIds, [12, 55, 88]);
    });

    test('falls back to 0 for an unparseable id', () {
      final outfit = Outfit.fromJson({'outfit_id': 'not-a-number'});
      expect(outfit.id, 0);
    });

    // An external API can serialize an integer id as a float (e.g. 101.0);
    // that must parse to 101, not silently collapse to 0.
    test('parses ids given as a float, same as ints', () {
      final outfit = Outfit.fromJson({
        'outfit_id': 101.0,
        'group_id': 12.0,
        'garment_ids': [12.0, 55, '88'],
      });

      expect(outfit.id, 101);
      expect(outfit.groupId, 12);
      expect(outfit.garmentIds, [12, 55, 88]);
    });

    test('accepts season/style as a single string, not just a list', () {
      final outfit = Outfit.fromJson({
        'outfit_id': 1,
        'season': 'summer',
        'style': 'minimal',
      });

      expect(outfit.seasons, ['summer']);
      expect(outfit.style, ['minimal']);
    });

    test('treats an empty season/style string as no tags, not one blank tag', () {
      final outfit = Outfit.fromJson({'outfit_id': 1, 'season': '', 'style': ''});
      expect(outfit.seasons, isEmpty);
      expect(outfit.style, isEmpty);
    });

    test('joins a reasoning list into newline-separated text', () {
      final outfit = Outfit.fromJson({
        'outfit_id': 1,
        'reasoning': ['Warm layers for the forecast.', 'Matches your saved style.'],
      });
      expect(
        outfit.reasoning,
        'Warm layers for the forecast.\nMatches your saved style.',
      );
    });

    test('accepts reasoning as a plain string', () {
      final outfit = Outfit.fromJson({'outfit_id': 1, 'reasoning': 'Good for rain.'});
      expect(outfit.reasoning, 'Good for rain.');
    });

    test('treats is_favorite of 1 the same as true (loose backend typing)', () {
      final outfit = Outfit.fromJson({'outfit_id': 1, 'is_favorite': 1});
      expect(outfit.isFavorite, isTrue);
    });
  });

  group('Outfit.copyWith', () {
    Outfit build() => Outfit.fromJson({
      'outfit_id': 1,
      'group_id': 12,
      'result_image_url': 'https://example.com/a.jpg',
    });

    test('overrides only the given fields, keeps the rest', () {
      final original = build();
      final updated = original.copyWith(name: 'New Name', isFavorite: true);

      expect(updated.name, 'New Name');
      expect(updated.isFavorite, isTrue);
      expect(updated.id, original.id);
      expect(updated.imageUrl, original.imageUrl);
    });

    test('coverOutfitId is left untouched when omitted', () {
      final withCover = build().copyWith(coverOutfitId: 55);
      final untouched = withCover.copyWith(name: 'Renamed');
      expect(untouched.coverOutfitId, 55);
    });

    test('clearCoverOutfitId nulls it out even though coverOutfitId itself is omitted', () {
      final withCover = build().copyWith(coverOutfitId: 55);
      final cleared = withCover.copyWith(clearCoverOutfitId: true);
      expect(cleared.coverOutfitId, isNull);
    });

    test('groupName is left untouched when omitted', () {
      final withName = build().copyWith(groupName: 'Weekend Look');
      final untouched = withName.copyWith(isFavorite: true);
      expect(untouched.groupName, 'Weekend Look');
    });

    test('clearGroupName nulls it out even though groupName itself is omitted', () {
      final withName = build().copyWith(groupName: 'Weekend Look');
      final cleared = withName.copyWith(clearGroupName: true);
      expect(cleared.groupName, isNull);
    });
  });

  group('Outfit.toJson', () {
    test('round-trips the fields it carries', () {
      final outfit = Outfit.fromJson({
        'outfit_id': 101,
        'group_id': 12,
        'group_type': 'general',
        'status': 'completed',
        'name': 'Relaxed City Layers',
        'garment_ids': [12, 55],
        'result_image_url': 'https://example.com/outfit.jpg',
        'season': ['autumn'],
        'style': ['streetwear'],
        'background_id': 3,
        'is_favorite': true,
      });

      final json = outfit.toJson();
      expect(json['outfit_id'], 101);
      expect(json['group_id'], 12);
      expect(json['name'], 'Relaxed City Layers');
      expect(json['garment_ids'], [12, 55]);
      expect(json['result_image_url'], 'https://example.com/outfit.jpg');
      expect(json['season'], ['autumn']);
      expect(json['style'], ['streetwear']);
      expect(json['background_id'], 3);
      expect(json['is_favorite'], true);
    });
  });
}
