import 'user_profile.dart';

/// Everything `GET /users/me` + the two try-on reference-photo endpoints
/// return, bundled so the Account / Settings / Try-on Profile screens share
/// one fetch (see `profileProvider`) instead of each calling
/// `getMyProfile` / `getBodyRef` / `getFaceReference` themselves.
class ProfileData {
  final UserProfile profile;

  /// Signed GCS URLs for the full-body / face try-on reference photos; null
  /// when the user hasn't set one.
  final String? bodyRefUrl;
  final String? faceRefUrl;

  const ProfileData({required this.profile, this.bodyRefUrl, this.faceRefUrl});

  ProfileData copyWith({UserProfile? profile}) => ProfileData(
    profile: profile ?? this.profile,
    bodyRefUrl: bodyRefUrl,
    faceRefUrl: faceRefUrl,
  );
}
