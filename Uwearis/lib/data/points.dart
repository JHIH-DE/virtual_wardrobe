/// An AI feature that spends points — the backend's `PointAction`, the key
/// of `GET /points`' `costs`.
enum PointsAction {
  tryOn('try_on'),
  garmentAnalysis('garment_analysis'),
  flatLay('flat_lay'),
  baseModel('base_model'),
  closetAnalysis('closet_analysis'),
  outfitAdvice('outfit_advice'),
  matchLookReference('match_look_reference'),
  matchLookMatch('match_look_match'),
  tripOutfits('trip_outfits'),
  tripPacking('trip_packing');

  final String apiValue;
  const PointsAction(this.apiValue);

  /// Null for a feature added after this build.
  static PointsAction? fromApiValue(String? value) {
    for (final action in values) {
      if (action.apiValue == value) return action;
    }
    return null;
  }
}

/// Why a balance changed. Values added after this build parse to [unknown].
enum PointsTransactionKind {
  dailyGrant('daily_grant'),
  charge('charge'),
  refund('refund'),
  adjust('adjust'),
  unknown('');

  final String apiValue;
  const PointsTransactionKind(this.apiValue);

  static PointsTransactionKind fromApiValue(String? value) {
    for (final kind in values) {
      if (kind != unknown && kind.apiValue == value) return kind;
    }
    return unknown;
  }
}

/// `GET /points`: balance, today's grant, subscription and per-feature costs.
class PointsSummary {
  final int balance;

  /// The daily grant tops the balance up to at most this.
  final int cap;

  /// Points this account gets each day (more with a subscription).
  final int dailyGrant;
  final bool claimedToday;

  /// The next grant (00:00 Taipei), in device-local time.
  final DateTime nextClaimAt;
  final bool subscriptionActive;
  final DateTime? subscriptionExpiresAt;

  /// Keyed by `PointsAction.apiValue`; prices are server config.
  final Map<String, int> costs;

  const PointsSummary({
    required this.balance,
    required this.cap,
    required this.dailyGrant,
    required this.claimedToday,
    required this.nextClaimAt,
    this.subscriptionActive = false,
    this.subscriptionExpiresAt,
    this.costs = const {},
  });

  int? costOf(PointsAction action) => costs[action.apiValue];

  factory PointsSummary.fromJson(Map<String, dynamic> json) {
    final subscription = json['subscription'] as Map<String, dynamic>?;
    final rawExpiry = subscription?['expires_at'] as String?;
    final rawCosts = json['costs'] as Map<String, dynamic>? ?? const {};
    return PointsSummary(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      cap: (json['cap'] as num?)?.toInt() ?? 0,
      dailyGrant: (json['daily_grant'] as num?)?.toInt() ?? 0,
      claimedToday: json['claimed_today'] as bool? ?? false,
      nextClaimAt: DateTime.parse(json['next_claim_at'] as String).toLocal(),
      subscriptionActive: subscription?['active'] as bool? ?? false,
      subscriptionExpiresAt: rawExpiry == null
          ? null
          : DateTime.parse(rawExpiry).toLocal(),
      costs: {
        for (final entry in rawCosts.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      },
    );
  }
}

/// One row of `GET /points/transactions`.
class PointsTransaction {
  final int id;

  /// Negative for a charge.
  final int delta;
  final int balanceAfter;
  final PointsTransactionKind kind;

  /// Null for a grant, a manual adjustment, or an action unknown to this
  /// build ([rawAction] keeps the wire value).
  final PointsAction? action;
  final String? rawAction;

  /// Device-local time.
  final DateTime createdAt;

  const PointsTransaction({
    required this.id,
    required this.delta,
    required this.balanceAfter,
    required this.kind,
    required this.createdAt,
    this.action,
    this.rawAction,
  });

  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action'] as String?;
    return PointsTransaction(
      id: (json['id'] as num).toInt(),
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      kind: PointsTransactionKind.fromApiValue(json['kind'] as String?),
      action: PointsAction.fromApiValue(rawAction),
      rawAction: rawAction,
      createdAt: parseTaipeiTimestamp(json['created_at'] as String),
    );
  }
}

class PointsTransactionPage {
  final List<PointsTransaction> items;
  final int total;
  final int page;
  final int size;

  const PointsTransactionPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  bool get hasMore => page * size < total;

  factory PointsTransactionPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return PointsTransactionPage(
      items: [
        for (final item in rawItems)
          PointsTransaction.fromJson(item as Map<String, dynamic>),
      ],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? rawItems.length,
    );
  }
}

/// Transaction `created_at` is sent without an offset and means Taipei time
/// (fixed UTC+8). One that does carry an offset is honoured as-is.
DateTime parseTaipeiTimestamp(String raw) {
  final parsed = DateTime.parse(raw);
  final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw);
  if (hasOffset) return parsed.toLocal();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).subtract(const Duration(hours: 8)).toLocal();
}
