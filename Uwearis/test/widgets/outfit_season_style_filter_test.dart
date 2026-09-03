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
}
