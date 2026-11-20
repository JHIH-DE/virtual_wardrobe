/// The signed-in user's profile (`/users/me`). `locale` is write-only, an
/// `updateMyProfile` argument only.
class UserProfile {
  final String name;
  final String? gender;
  final String? location;

  /// Where [location] is, when it was picked with coordinates; both or
  /// neither. Older profiles only have the name.
  final double? locationLatitude;
  final double? locationLongitude;
  final String? email;

  /// Signed GCS URL; null until the user sets an avatar.
  final String? avatarObjectUrl;

  /// Backend-derived stable cache key for [avatarObjectUrl]; prefer it over
  /// the signed URL itself wherever one is available.
  final String? avatarCacheKey;

  /// The wire's `birthday` (`yyyy-MM-dd`); null if absent or unparseable.
  final DateTime? birthDate;

  /// Always metric; [unitSystem] is only the user's display unit.
  final double? height;
  final double? weight;
  final String? unitSystem;

  /// Uwearis Plus end; null if never subscribed. Read-only on the backend.
  final DateTime? subscriptionExpiresAt;

  /// How much warmer (+) or colder (−) than the forecast the user feels, in
  /// °C; null if never set.
  final double? temperatureOffsetC;

  const UserProfile({
    this.name = '',
    this.gender,
    this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.email,
    this.avatarObjectUrl,
    this.avatarCacheKey,
    this.birthDate,
    this.height,
    this.weight,
    this.unitSystem,
    this.subscriptionExpiresAt,
    this.temperatureOffsetC,
  });

  bool get isSubscribed {
    final expiresAt = subscriptionExpiresAt;
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawBirthday = json['birthday'] as String?;
    final lat = (json['location_latitude'] as num?)?.toDouble();
    final lon = (json['location_longitude'] as num?)?.toDouble();
    final hasCoordinates = lat != null && lon != null;
    return UserProfile(
      name: (json['name'] as String?) ?? '',
      gender: json['gender'] as String?,
      location: json['location'] as String?,
      locationLatitude: hasCoordinates ? lat : null,
      locationLongitude: hasCoordinates ? lon : null,
      email: json['email'] as String?,
      avatarObjectUrl: json['avatar_object_url'] as String?,
      avatarCacheKey: json['avatar_cache_key'] as String?,
      birthDate: (rawBirthday == null || rawBirthday.isEmpty)
          ? null
          : DateTime.tryParse(rawBirthday),
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      unitSystem: json['unit_system'] as String?,
      subscriptionExpiresAt: DateTime.tryParse(
        (json['subscription_expires_at'] as String?) ?? '',
      )?.toLocal(),
      temperatureOffsetC: (json['temperature_offset_c'] as num?)?.toDouble(),
    );
  }
}
