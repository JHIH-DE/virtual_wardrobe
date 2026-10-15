import 'user_profile.dart';

/// `GET /users/me` (profile + reference/base-model signed URLs), shared via
/// `profileProvider`.
class ProfileData {
  final UserProfile profile;

  /// Null when the user hasn't set one.
  final String? bodyRefUrl;
  final String? faceRefUrl;

  /// Null until generated. A fresh generation is set in memory via
  /// `ProfileNotifier.setBaseModelUrl` without a re-fetch.
  final String? baseModelUrl;

  const ProfileData({
    required this.profile,
    this.bodyRefUrl,
    this.faceRefUrl,
    this.baseModelUrl,
  });

  ProfileData copyWith({
    UserProfile? profile,
    String? bodyRefUrl,
    String? faceRefUrl,
    String? baseModelUrl,
  }) => ProfileData(
    profile: profile ?? this.profile,
    bodyRefUrl: bodyRefUrl ?? this.bodyRefUrl,
    faceRefUrl: faceRefUrl ?? this.faceRefUrl,
    baseModelUrl: baseModelUrl ?? this.baseModelUrl,
  );

  /// The backend's OpenAPI example value "string" sometimes leaks through as
  /// a URL; treat it as "no photo". Use this rather than re-deriving it.
  static bool isRealPhotoUrl(String? url) =>
      url != null && url.isNotEmpty && url != 'string';

  bool get hasFaceReference => isRealPhotoUrl(faceRefUrl);
  bool get hasBodyReference => isRealPhotoUrl(bodyRefUrl);
}
