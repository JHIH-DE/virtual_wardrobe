import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/occasion_type.dart';

void main() {
  group('OccasionType', () {
    test('apiValue round-trips through occasionTypeFromApiValue for every value', () {
      for (final occasion in OccasionType.values) {
        expect(occasionTypeFromApiValue(occasion.apiValue), occasion);
      }
    });

    test('apiValue matches the enum name (persisted locally, must stay stable)', () {
      expect(OccasionType.work.apiValue, 'work');
      expect(OccasionType.workout.apiValue, 'workout');
    });

    test('occasionTypeFromApiValue returns null for an unrecognized value', () {
      expect(occasionTypeFromApiValue('sleeping'), isNull);
    });
  });
}
