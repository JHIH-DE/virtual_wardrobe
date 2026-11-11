/// The signed-in user's profile (`/users/me`). Write-only fields
/// (`temperature_offset_c`, `locale`) are only `updateMyProfile` arguments.
class UserProfile {
  final String name;
  final String? gender;
  final String? location;
  final String? email;

  /// Signed GCS URL; null until the user sets an avatar.
  final String? avatarObjectUrl;

  /// The wire's `birthday` (`yyyy-MM-dd`); null if absent or unparseable.
  final DateTime? birthDate;

  /// Always metric; [unitSystem] is only the user's display unit.
  final double? height;
  final double? weight;
  final String? unitSystem;

  /// Uwearis Plus end; null if never subscribed. Read-only on the backend.
  final DateTime? subscriptionExpiresAt;

  const UserProfile({
    this.name = '',
    this.gender,
    this.location,
    this.email,
    this.avatarObjectUrl,
    this.birthDate,
    this.height,
    this.weight,
    this.unitSystem,
    this.subscriptionExpiresAt,
  });

  bool get isSubscribed {
    final expiresAt = subscriptionExpiresAt;
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawBirthday = json['birthday'] as String?;
    return UserProfile(
      name: (json['name'] as String?) ?? '',
      gender: json['gender'] as String?,
      location: json['location'] as String?,
      email: json['email'] as String?,
      avatarObjectUrl: json['avatar_object_url'] as String?,
      birthDate: (rawBirthday == null || rawBirthday.isEmpty)
          ? null
          : DateTime.tryParse(rawBirthday),
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      unitSystem: json['unit_system'] as String?,
      subscriptionExpiresAt: DateTime.tryParse(
        (json['subscription_expires_at'] as String?) ?? '',
      )?.toLocal(),
    );
  }
}
