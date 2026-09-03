/// The signed-in user's profile (`GET /users/me`, `PATCH /users/me` —
/// `ProfileService.getMyProfile` / `updateMyProfile`). Only the fields the
/// app actually reads back are modelled here; write-only fields
/// (`weekly_schedule`, `temperature_offset_c`, `locale`) stay as plain
/// arguments on `updateMyProfile` since nothing consumes them from the
/// response. Read-only, never patched in place — no `copyWith`.
class UserProfile {
  final String name;
  final String? gender;
  final String? location;
  final String? email;

  /// `avatar_object_url` — a signed GCS URL, may be null before the user
  /// sets an avatar.
  final String? avatarObjectUrl;

  /// Parsed from the wire's `birthday` (`yyyy-MM-dd`); null if absent or
  /// unparseable.
  final DateTime? birthDate;

  /// `height` / `weight` — the backend stores these in metric; the unit the
  /// user edits in is [unitSystem].
  final double? height;
  final double? weight;
  final String? unitSystem;

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
  });

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
    );
  }
}
