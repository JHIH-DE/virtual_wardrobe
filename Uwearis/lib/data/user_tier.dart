/// The user's plan (`tier` on `GET /users/me`, read-only). Shown to users as
/// Gold / Silver / Bronze. The tier only names the plan — the actual daily
/// try-on limit for each tier is server config, so never derive a count from
/// it; read `GET /outfit/generation-quota` for that.
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

/// Unknown or missing values fall back to [UserTier.bronze], the backend's
/// default tier, rather than showing no plan at all.
UserTier userTierFromApiValue(String? value) {
  for (final tier in UserTier.values) {
    if (tier.apiValue == value) return tier;
  }
  return UserTier.bronze;
}
