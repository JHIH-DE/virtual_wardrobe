/// `tier` on `GET /users/me`. Only names the plan: daily limits are server
/// config, so read `GET /outfit/generation-quota`, never derive them here.
enum UserTier {
  /// `tier_1` — unlimited try-on generation.
  gold,

  /// `tier_2`.
  silver,

  /// `tier_3` — the backend's default for every new account.
  bronze,
}

extension UserTierApi on UserTier {
  String get apiValue {
    switch (this) {
      case UserTier.gold:
        return 'tier_1';
      case UserTier.silver:
        return 'tier_2';
      case UserTier.bronze:
        return 'tier_3';
    }
  }
}

/// Unknown or missing values fall back to the backend default, bronze.
UserTier userTierFromApiValue(String? value) {
  for (final tier in UserTier.values) {
    if (tier.apiValue == value) return tier;
  }
  return UserTier.bronze;
}
