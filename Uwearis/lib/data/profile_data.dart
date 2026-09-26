import 'user_profile.dart';

/// Everything `GET /users/me` + the two try-on reference-photo endpoints
/// return, bundled so the Account / Settings / My Virtual Model screens share
/// one fetch (see `profileProvider`) instead of each calling
/// `getMyProfile` / `getBodyRef` / `getFaceReference` themselves.
class ProfileData {
  final UserProfile profile;

  /// Signed GCS URLs for the full-body / face try-on reference photos; null
  /// when the user hasn't set one.
  final String? bodyRefUrl;
  final String? faceRefUrl;

  /// Signed GCS URL for the generated AI base model (`base_model_object_url`
  /// on `GET /users/me`, alongside the two reference-photo URLs above); null
  /// until the user has generated one. Also set in-memory straight from
  /// `ProfileService.generateBaseModel`'s own response (see
  /// `ProfileNotifier.setBaseModelUrl`) so a fresh generation shows up
  /// immediately without waiting on a re-fetch.
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

  /// The backend's OpenAPI schema example ("string") occasionally leaks
  /// through as a literal placeholder value instead of a real URL/null —
  /// treat it the same as "no photo set". Canonical version of a check
  /// otherwise re-derived per screen (settings_page.dart's
  /// `_hasFaceReference`/`_hasBodyReference`, my_virtual_model_page.dart's
  /// `_resolvedUrl`) — new call sites should use [hasFaceReference] /
  /// [hasBodyReference] below instead of re-deriving this.
  static bool isRealPhotoUrl(String? url) =>
      url != null && url.isNotEmpty && url != 'string';

  bool get hasFaceReference => isRealPhotoUrl(faceRefUrl);
  bool get hasBodyReference => isRealPhotoUrl(bodyRefUrl);
}
