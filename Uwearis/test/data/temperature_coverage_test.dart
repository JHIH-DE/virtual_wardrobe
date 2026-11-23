import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/temperature_coverage.dart';

void main() {
  group('TemperatureCoverage.fromJson', () {
    test('parses status, open ends and float-valued numbers', () {
      final c = TemperatureCoverage.fromJson({
        'temperature_offset_c': -3,
        'usable_outfit_count': 4.0,
        'enough_count': 3,
        'bands': [
          {'min_c': null, 'max_c': 12.5, 'outfit_count': 0, 'status': 'none'},
          {'min_c': 12.5, 'max_c': 15, 'outfit_count': 2.0, 'status': 'few'},
          {'min_c': 33, 'max_c': null, 'outfit_count': 4, 'status': 'enough'},
        ],
      });

      expect(c.temperatureOffsetC, -3);
      expect(c.usableOutfitCount, 4);
      expect(c.bands.map((b) => b.status), [
        TemperatureCoverageStatus.none,
        TemperatureCoverageStatus.few,
        TemperatureCoverageStatus.enough,
      ]);
      expect(c.bands.first.minC, isNull);
      expect(c.bands.first.maxC, 12.5);
      expect(c.bands[1].outfitCount, 2);
      expect(c.bands.last.maxC, isNull);
    });

    test('reads key and label; a blank or missing label is null', () {
      final c = TemperatureCoverage.fromJson({
        'enough_count': 3,
        'bands': [
          {
            'key': 'cool',
            'label': '微涼',
            'min_c': 15,
            'max_c': 20,
            'outfit_count': 42,
            'status': 'enough',
          },
          {'key': 'mild', 'label': '  ', 'min_c': 20, 'max_c': 25},
          {'min_c': 25, 'max_c': 29},
        ],
      });

      expect(c.bands.map((b) => b.key), ['cool', 'mild', null]);
      expect(c.bands.map((b) => b.label), ['微涼', null, null]);
    });

    test('an unknown status falls back to the count', () {
      final c = TemperatureCoverage.fromJson({
        'enough_count': 3,
        'bands': [
          {'min_c': 0, 'max_c': 3, 'outfit_count': 0, 'status': 'later'},
          {'min_c': 3, 'max_c': 6, 'outfit_count': 2},
          {'min_c': 6, 'max_c': 9, 'outfit_count': 3},
        ],
      });

      expect(c.bands.map((b) => b.status), [
        TemperatureCoverageStatus.none,
        TemperatureCoverageStatus.few,
        TemperatureCoverageStatus.enough,
      ]);
    });
  });
}
