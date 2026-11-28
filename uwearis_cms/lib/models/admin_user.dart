/// Users as `/api/v1/admin/users/*` returns them (contract: backend
/// docs/requirements/cms_user_management.md).
library;

const _taipeiOffset = Duration(hours: 8);
final _hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// Taipei wall-clock time, so the CMS shows the same day the backend counts
/// in whatever timezone the browser is. A value without an offset is already
/// Taipei time.
DateTime? parseTaipei(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  if (!_hasOffset.hasMatch(value)) return parsed;
  final t = parsed.toUtc().add(_taipeiOffset);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatTaipeiDate(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)}';

String formatTaipei(DateTime t) =>
    '${formatTaipeiDate(t)} ${_two(t.hour)}:${_two(t.minute)}';

/// What the backend expects for a Taipei wall-clock time: always with its offset.
String toTaipeiIso(DateTime t) =>
    '${formatTaipeiDate(t)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}+08:00';

String? _str(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
int _int(Object? value) => (value as num?)?.toInt() ?? 0;
double? _double(Object? value) => (value as num?)?.toDouble();

String authProviderLabel(String? provider) => switch (provider) {
  'google' => 'Google',
  'apple' => 'Apple',
  'facebook' => 'Facebook',
  null => '—',
  _ => provider,
};

class AdminUserSummary {
  final int id;
  final String email;
  final String? name;
  final String? authProvider;
  final bool isAdmin;
  final int pointsBalance;
  final bool subscriptionActive;
  final DateTime? subscriptionExpiresAt;
  final DateTime? createdAt;

  const AdminUserSummary({
    required this.id,
    required this.email,
    this.name,
    this.authProvider,
    this.isAdmin = false,
    this.pointsBalance = 0,
    this.subscriptionActive = false,
    this.subscriptionExpiresAt,
    this.createdAt,
  });

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) =>
      AdminUserSummary(
        id: _int(json['id']),
        email: json['email'] as String? ?? '',
        name: _str(json['name']),
        authProvider: _str(json['auth_provider']),
        isAdmin: json['is_admin'] == true,
        pointsBalance: _int(json['points_balance']),
        subscriptionActive: json['subscription_active'] == true,
        subscriptionExpiresAt: parseTaipei(json['subscription_expires_at']),
        createdAt: parseTaipei(json['created_at']),
      );
}

class AdminUser {
  final int id;
  final String email;
  final String? name;
  final String? gender;
  final String? birthday;
  final double? height;
  final double? weight;
  final String unitSystem;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double? temperatureOffsetC;
  final String locale;
  final bool isAdmin;
  final String? authProvider;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? welcomeStartsOn;
  final String? avatarUrl;
  final String? baseModelUrl;

  final int pointsBalance;
  final int pointsCap;
  final int dailyGrant;
  final bool claimedToday;
  final bool subscriptionActive;
  final DateTime? subscriptionExpiresAt;

  const AdminUser({
    required this.id,
    required this.email,
    this.name,
    this.gender,
    this.birthday,
    this.height,
    this.weight,
    this.unitSystem = 'metric',
    this.location,
    this.latitude,
    this.longitude,
    this.temperatureOffsetC,
    this.locale = 'en',
    this.isAdmin = false,
    this.authProvider,
    this.createdAt,
    this.updatedAt,
    this.welcomeStartsOn,
    this.avatarUrl,
    this.baseModelUrl,
    this.pointsBalance = 0,
    this.pointsCap = 0,
    this.dailyGrant = 0,
    this.claimedToday = false,
    this.subscriptionActive = false,
    this.subscriptionExpiresAt,
  });

  String get displayName => name ?? email;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final points = json['points'] as Map<String, dynamic>? ?? const {};
    final subscription =
        points['subscription'] as Map<String, dynamic>? ?? const {};
    return AdminUser(
      id: _int(json['id']),
      email: json['email'] as String? ?? '',
      name: _str(json['name']),
      gender: _str(json['gender']),
      birthday: _str(json['birthday']),
      height: _double(json['height']),
      weight: _double(json['weight']),
      unitSystem: _str(json['unit_system']) ?? 'metric',
      location: _str(json['location']),
      latitude: _double(json['location_latitude']),
      longitude: _double(json['location_longitude']),
      temperatureOffsetC: _double(json['temperature_offset_c']),
      locale: _str(json['locale']) ?? 'en',
      isAdmin: json['is_admin'] == true,
      authProvider: _str(json['auth_provider']),
      createdAt: parseTaipei(json['created_at']),
      updatedAt: parseTaipei(json['updated_at']),
      welcomeStartsOn:
          _str(json['welcome_starts_on']) ?? _str(points['welcome_starts_on']),
      avatarUrl: _str(json['avatar_object_url']),
      baseModelUrl: _str(json['base_model_object_url']),
      pointsBalance: _int(points['balance'] ?? json['points_balance']),
      pointsCap: _int(points['cap']),
      dailyGrant: _int(points['daily_grant']),
      claimedToday: points['claimed_today'] == true,
      subscriptionActive: subscription['active'] == true,
      subscriptionExpiresAt: parseTaipei(
        subscription['expires_at'] ?? json['subscription_expires_at'],
      ),
    );
  }
}

enum PointKind {
  dailyGrant('daily_grant', '每日發點'),
  charge('charge', 'AI 扣點'),
  refund('refund', '退回'),
  adjust('adjust', '手動調整'),
  other('', '其他');

  final String apiValue;
  final String label;
  const PointKind(this.apiValue, this.label);

  static PointKind fromApiValue(Object? value) =>
      values.firstWhere((k) => k.apiValue == value, orElse: () => other);
}

const pointActionLabels = {
  'try_on': '試穿',
  'garment_analysis': '衣物分析',
  'flat_lay': '平拍圖',
  'base_model': '基礎模特兒',
  'closet_analysis': '衣櫥分析',
  'outfit_advice': '穿搭建議',
  'match_look_reference': 'Match a Look 參考圖',
  'match_look_match': 'Match a Look 配對',
  'trip_outfits': 'Trip 穿搭',
  'trip_packing': 'Trip 打包清單',
};

class PointTransaction {
  final int id;
  final int delta;
  final int balanceAfter;
  final PointKind kind;
  final String? action;
  final String? note;
  final DateTime? createdAt;
  final String? adminEmail;

  const PointTransaction({
    required this.id,
    required this.delta,
    required this.balanceAfter,
    required this.kind,
    this.action,
    this.note,
    this.createdAt,
    this.adminEmail,
  });

  String? get actionLabel {
    final action = this.action;
    return action == null ? null : pointActionLabels[action] ?? action;
  }

  factory PointTransaction.fromJson(Map<String, dynamic> json) =>
      PointTransaction(
        id: _int(json['id']),
        delta: _int(json['delta']),
        balanceAfter: _int(json['balance_after']),
        kind: PointKind.fromApiValue(json['kind']),
        action: _str(json['action']),
        note: _str(json['note']),
        createdAt: parseTaipei(json['created_at']),
        adminEmail: _str(json['admin_email']),
      );
}
