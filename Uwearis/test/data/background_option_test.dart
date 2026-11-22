import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/background_option.dart';

void main() {
  group('fromJson', () {
    test('reads label and category', () {
      final b = BackgroundOption.fromJson(const {
        'id': 16,
        'name': 'tokyo_street_2',
        'label': '東京街頭 2',
        'category': 'urban',
      });
      expect(b.label, '東京街頭 2');
      expect(b.category, BackgroundCategory.urban);
    });

    test(
      'a backend without categories means indoor; an unknown one, other',
      () {
        expect(
          BackgroundOption.fromJson(const {'id': 1, 'name': 'x'}).category,
          BackgroundCategory.indoor,
        );
        expect(
          BackgroundCategory.fromApiValue('space'),
          BackgroundCategory.other,
        );
        expect(
          BackgroundCategory.fromApiValue('nature'),
          BackgroundCategory.nature,
        );
      },
    );
  });

  group('fallbackLabel', () {
    test('reads a name as title-cased words', () {
      String label(String name) =>
          BackgroundOption(id: 1, name: name).fallbackLabel;
      expect(label('coffeehouse'), 'Coffeehouse');
      expect(label('tokyo_street'), 'Tokyo Street');
      expect(label('rooftop__garden_'), 'Rooftop Garden');
      expect(label(''), '');
    });
  });

  group('defaultBackground', () {
    test('is the fitting room wherever it is listed', () {
      final pick = defaultBackground(const [
        BackgroundOption(id: 8, name: 'coffeehouse'),
        BackgroundOption(id: 0, name: 'default_fitting_room'),
      ]);
      expect(pick?.id, 0);
    });

    test('falls back to the first one, or none', () {
      expect(
        defaultBackground(const [
          BackgroundOption(id: 8, name: 'coffeehouse'),
          BackgroundOption(id: 7, name: 'tokyo_street'),
        ])?.id,
        8,
      );
      expect(defaultBackground(const []), isNull);
    });
  });
}
