import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/widgets/common/buttons/outfit_season_style_filter.dart';

Outfit _o(int id, {List<String> season = const [], List<String> style = const []}) =>
    Outfit.fromJson({
      'outfit_id': id,
      'group_id': id * 10,
      'result_image_url': '',
      'season': season,
      'style': style,
    });

void main() {
  final all = [
    _o(1, season: ['Summer'], style: ['smart_casual']),
    _o(2, season: ['Winter'], style: ['formal']),
    _o(3, season: ['Summer', 'Spring'], style: ['casual']),
  ];

  test('starts inactive and passes everything through', () {
    final f = OutfitSeasonStyleFilter();
    expect(f.isActive, isFalse);
    expect(f.apply(all).length, 3);
  });

  test('season filter is case-insensitive', () {
    final f = OutfitSeasonStyleFilter()..seasons = {'summer'};
    expect(f.isActive, isTrue);
    expect(f.apply(all).map((o) => o.id), [1, 3]);
  });

  test('style filter normalizes separators/case ("Smart Casual" == "smart_casual")', () {
    final f = OutfitSeasonStyleFilter()..styles = {'Smart Casual'};
    expect(f.apply(all).map((o) => o.id), [1]);
  });

  test('season and style combine (AND)', () {
    final f = OutfitSeasonStyleFilter()
      ..seasons = {'Summer'}
      ..styles = {'Casual'};
    expect(f.apply(all).map((o) => o.id), [3]);
  });

  group('visible options', () {
    test('only offers season/style tags present in the outfits', () {
      final f = OutfitSeasonStyleFilter();
      // all[] uses Summer/Winter/Spring and smart_casual (Autumn + the rest
      // of the style vocab never appear).
      expect(f.visibleSeasonOptions(all), ['Spring', 'Summer', 'Winter']);
      expect(f.visibleStyleOptions(all), ['Smart Casual']);
    });

    test('matches style tags regardless of separator/case', () {
      final f = OutfitSeasonStyleFilter();
      final outfits = [_o(1, style: ['STREET_WEAR'])];
      expect(f.visibleStyleOptions(outfits), ['Streetwear']);
    });

    test('keeps a selected value even once it is no longer present', () {
      final f = OutfitSeasonStyleFilter()..styles = {'Vintage'};
      // No outfit is tagged Vintage, but the active selection must stay
      // visible (alongside the tags actually in use) so the user can clear
      // it. Order still follows styleOptions.
      expect(f.visibleStyleOptions(all), ['Smart Casual', 'Vintage']);
    });

    test('an empty outfit list yields no options', () {
      final f = OutfitSeasonStyleFilter();
      expect(f.visibleSeasonOptions(const []), isEmpty);
      expect(f.visibleStyleOptions(const []), isEmpty);
    });
  });
}
