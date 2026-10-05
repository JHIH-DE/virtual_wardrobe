import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/data/user_tier.dart';

void main() {
  group('userTierFromApiValue', () {
    test('maps each backend tier to its medal', () {
      expect(userTierFromApiValue('tier_1'), UserTier.gold);
      expect(userTierFromApiValue('tier_2'), UserTier.silver);
      expect(userTierFromApiValue('tier_3'), UserTier.bronze);
    });

    test('unknown or missing values fall back to bronze', () {
      expect(userTierFromApiValue(null), UserTier.bronze);
      expect(userTierFromApiValue('tier_9'), UserTier.bronze);
    });
  });

  test('UserProfile.fromJson parses tier', () {
    expect(UserProfile.fromJson({'tier': 'tier_1'}).tier, UserTier.gold);
    expect(UserProfile.fromJson({}).tier, UserTier.bronze);
  });
}
