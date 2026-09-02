import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/style_profile.dart';
import 'package:uwearis/data/style_type.dart';

void main() {
  group('StyleProfileItem.fromJson', () {
    test('parses a recognized style', () {
      final item = StyleProfileItem.fromJson({'style': 'smart_casual', 'count': 5});
      expect(item.style, StyleType.smartCasual);
      expect(item.rawStyle, 'smart_casual');
      expect(item.count, 5);
    });

    test('keeps rawStyle but leaves style null for an unrecognized backend value', () {
      final item = StyleProfileItem.fromJson({'style': 'goth', 'count': 2});
      expect(item.style, isNull);
      expect(item.rawStyle, 'goth');
      expect(item.count, 2);
    });

    test('defaults missing fields', () {
      final item = StyleProfileItem.fromJson({});
      expect(item.style, isNull);
      expect(item.rawStyle, '');
      expect(item.count, 0);
    });

    test('accepts count as a double and truncates to int', () {
      final item = StyleProfileItem.fromJson({'style': 'minimal', 'count': 3.0});
      expect(item.count, 3);
    });
  });
}
