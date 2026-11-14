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

  /// Backend-derived stable cache keys for the three URLs above; prefer
  /// them over the signed URL / local version-counter key wherever one is
  /// available. Unlike the URLs, unaffected by a plain signed-URL refresh.
  final String? bodyRefCacheKey;
  final String? faceRefCacheKey;
  final String? baseModelCacheKey;

  const ProfileData({
    required this.profile,
    this.bodyRefUrl,
    this.faceRefUrl,
    this.baseModelUrl,
    this.bodyRefCacheKey,
    this.faceRefCacheKey,
    this.baseModelCacheKey,
  });

  /// The cache key setters pass [bodyRefCacheKey] etc. even when `null` (a
  /// fresh upload against a backend that hasn't deployed the field), so
  /// those three use [setBodyRefCacheKey] flags rather than `??`-merging —
  /// otherwise a stale key from the previous photo would survive and could
  /// pair with the new URL under the old photo's disk-cache entry.
  ProfileData copyWith({
    UserProfile? profile,
    String? bodyRefUrl,
    String? faceRefUrl,
    String? baseModelUrl,
    String? bodyRefCacheKey,
    String? faceRefCacheKey,
    String? baseModelCacheKey,
    bool setBodyRefCacheKey = false,
    bool setFaceRefCacheKey = false,
    bool setBaseModelCacheKey = false,
  }) => ProfileData(
    profile: profile ?? this.profile,
    bodyRefUrl: bodyRefUrl ?? this.bodyRefUrl,
    faceRefUrl: faceRefUrl ?? this.faceRefUrl,
    baseModelUrl: baseModelUrl ?? this.baseModelUrl,
    bodyRefCacheKey: setBodyRefCacheKey ? bodyRefCacheKey : this.bodyRefCacheKey,
    faceRefCacheKey: setFaceRefCacheKey ? faceRefCacheKey : this.faceRefCacheKey,
    baseModelCacheKey: setBaseModelCacheKey
        ? baseModelCacheKey
        : this.baseModelCacheKey,
  );

  /// The backend's OpenAPI example value "string" sometimes leaks through as
  /// a URL; treat it as "no photo". Use this rather than re-deriving it.
  static bool isRealPhotoUrl(String? url) =>
      url != null && url.isNotEmpty && url != 'string';

  bool get hasFaceReference => isRealPhotoUrl(faceRefUrl);
  bool get hasBodyReference => isRealPhotoUrl(bodyRefUrl);
}

/// An upload/generate `complete` response's `object_url` plus its
/// `object_cache_key` (null against a backend that hasn't deployed the
/// field yet).
class UploadedImage {
  final String url;
  final String? cacheKey;

  const UploadedImage({required this.url, this.cacheKey});
}
