/// The cache key to use for an image: the backend's own `*_cache_key` when
/// present (stable across re-signed URLs, restarts and devices), else
/// [fallback] (the local version-counter key, for a backend that hasn't
/// deployed the field yet, or a photo that has none).
String? imageCacheKey(String? backendKey, String? fallback) =>
    (backendKey != null && backendKey.isNotEmpty) ? backendKey : fallback;

/// Version counter per image identity (e.g. `outfit-job-{id}`) for images
/// the backend overwrites at the same URL; fold [versionOf] into the cache
/// key. Seeded with the current time, not 0: the keys land in the on-disk
/// image cache, so a restart starting at 0 could hit a stale entry.
class ImageCacheBust {
  ImageCacheBust._();

  static final Map<String, int> _versions = {};

  static int versionOf(String key) =>
      _versions[key] ??= DateTime.now().millisecondsSinceEpoch;

  static void bump(String key) {
    _versions[key] = versionOf(key) + 1;
  }
}
