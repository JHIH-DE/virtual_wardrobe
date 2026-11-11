/// A `GET /points` `data` object.
Map<String, dynamic> pointsSummaryJson({
  int balance = 140,
  int dailyGrant = 15,
  bool claimedToday = true,
  String? subscriptionExpiresAt,
  Map<String, int> costs = const {'try_on': 30, 'garment_analysis': 1},
}) => {
  'balance': balance,
  'cap': 30000,
  'daily_grant': dailyGrant,
  'claimed_today': claimedToday,
  'next_claim_at': '2026-11-10T00:00:00+08:00',
  'subscription': {
    'active': subscriptionExpiresAt != null,
    'expires_at': subscriptionExpiresAt,
  },
  'costs': costs,
};

/// True for `GET /api/v1/points` (not its sub-paths).
bool isPointsSummaryPath(String path) => path.endsWith('/points');
