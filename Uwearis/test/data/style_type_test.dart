import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/style_type.dart';

void main() {
  group('StyleType', () {
    test('apiValue round-trips through styleTypeFromApiValue for every value', () {
      for (final style in StyleType.values) {
        expect(styleTypeFromApiValue(style.apiValue), style);
      }
    });

    test('smartCasual maps to the snake_case wire value, not the enum name', () {
      // The one non-derivable mapping in this enum — every other case's
      // apiValue equals its Dart name, so a typo here is the one most
      // likely to slip through unnoticed.
      expect(StyleType.smartCasual.apiValue, 'smart_casual');
    });

    test('styleTypeFromApiValue returns null for an unrecognized value', () {
      expect(styleTypeFromApiValue('gothic'), isNull);
    });
  });
}
