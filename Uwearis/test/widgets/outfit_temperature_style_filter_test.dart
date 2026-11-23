import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/outfit_group.dart';
import 'package:uwearis/data/outfit_temperature_band.dart';
import 'package:uwearis/features/widgets/common/buttons/outfit_temperature_style_filter.dart';

Outfit _o(int id, {int? minC, int? maxC, List<String> style = const []}) =>
    Outfit.fromJson({
      'outfit_id': id,
      'group_id': id * 10,
      'result_image_url': '',
      'suitable_temp_min_c': minC,
      'suitable_temp_max_c': maxC,
      'style': style,
    });

void main() {
  final all = [
    _o(1, minC: 25, maxC: 35, style: ['smart_casual']), // warm, hot
    _o(2, maxC: 8, style: ['formal']), // freezing, cold
    _o(3, minC: 18, maxC: 23, style: ['casual']), // cool, mild
  ];

  test('starts inactive and passes everything through', () {
    final f = OutfitTemperatureStyleFilter();
    expect(f.isActive, isFalse);
    expect(f.apply(all).length, 3);
  });

  test('a band matches every outfit whose range overlaps it', () {
    final f = OutfitTemperatureStyleFilter()..temperatures = {'hot'};
    expect(f.isActive, isTrue);
    expect(f.apply(all).map((o) => o.id), [1]);

    f.temperatures = {'mild', 'freezing'};
    expect(f.apply(all).map((o) => o.id), [2, 3]);
  });

  test('band edges are half-open, like the backend', () {
    // 20–25 ends where Warm (25–29) starts.
    final f = OutfitTemperatureStyleFilter()..temperatures = {'warm'};
    expect(f.apply([_o(1, minC: 20, maxC: 25)]), isEmpty);
    expect(f.apply([_o(2, minC: 20, maxC: 26)]).length, 1);
  });

  test('an outfit without a range, or an empty one, matches no band', () {
    final f = OutfitTemperatureStyleFilter()..temperatures = {'mild'};
    expect(f.apply([_o(1), _o(2, minC: 22, maxC: 22)]), isEmpty);
  });

  test('style filter matches older tag spellings ("Smart Casual")', () {
    final f = OutfitTemperatureStyleFilter()..styles = {'smart_casual'};
    expect(
      f
          .apply([
            ...all,
            _o(4, style: ['Smart Casual']),
          ])
          .map((o) => o.id),
      [1, 4],
    );
  });

  test('temperature and style combine (AND)', () {
    final f = OutfitTemperatureStyleFilter()
      ..temperatures = {'cool', 'hot'}
      ..styles = {'casual'};
    expect(f.apply(all).map((o) => o.id), [3]);
  });

  group('visible options', () {
    test('only offers bands and styles the outfits cover', () {
      final f = OutfitTemperatureStyleFilter();
      expect(f.visibleTemperatureOptions(all), [
        OutfitTemperatureBand.freezing,
        OutfitTemperatureBand.cold,
        OutfitTemperatureBand.cool,
        OutfitTemperatureBand.mild,
        OutfitTemperatureBand.warm,
        OutfitTemperatureBand.hot,
      ]);
      expect(f.visibleStyleOptions(all), ['smart_casual']);
    });

    test('matches style tags regardless of separator/case', () {
      final f = OutfitTemperatureStyleFilter();
      expect(
        f.visibleStyleOptions([
          _o(1, style: ['STREET_WEAR']),
        ]),
        ['streetwear'],
      );
    });

    test('keeps a selected value even once it is no longer present', () {
      final f = OutfitTemperatureStyleFilter()
        ..temperatures = {'chilly'}
        ..styles = {'vintage'};
      expect(
        f.visibleTemperatureOptions(all),
        contains(OutfitTemperatureBand.chilly),
      );
      expect(f.visibleStyleOptions(all), ['smart_casual', 'vintage']);
    });

    test('an empty outfit list yields no options', () {
      final f = OutfitTemperatureStyleFilter();
      expect(f.visibleTemperatureOptions(const []), isEmpty);
      expect(f.visibleStyleOptions(const []), isEmpty);
    });
  });
  group('groups', () {
    OutfitGroup group(int id, List<Outfit> versions, {int? cover}) =>
        OutfitGroup(groupId: id, coverOutfitId: cover, versions: versions);

    final mixed = group(10, [
      _o(1, minC: 25, maxC: 35), // warm, hot — the cover
      _o(2, minC: 15, maxC: 20), // cool
      _o(3, minC: 16, maxC: 21), // cool, mild
    ], cover: 1);
    final cold = group(20, [_o(4, maxC: 8)]);

    test('inactive: one cover per group, and no version filter', () {
      final f = OutfitTemperatureStyleFilter();
      expect(f.applyToGroups([mixed, cold]).map((o) => o.id), [1, 4]);
      expect(f.versionFilter, isNull);
    });

    test('a group shows when any version matches, on its first match', () {
      final f = OutfitTemperatureStyleFilter()..temperatures = {'cool'};
      final cards = f.applyToGroups([mixed, cold]);
      expect(cards.map((o) => o.id), [2]);
      expect(f.versionFilter!(mixed.versions[2]), isTrue);
      expect(f.versionFilter!(mixed.versions[0]), isFalse);
    });

    test('the cover stays the card while it matches', () {
      final f = OutfitTemperatureStyleFilter()..temperatures = {'hot'};
      expect(f.applyToGroups([mixed]).single.id, 1);
    });
  });
}
