/// Tracks a bump counter per stable image identity (e.g. `outfit-job-{id}`),
/// for images a backend endpoint can overwrite in place at their existing
/// URL (see `OutfitService.regenerateOutfit`) — a plain URL-keyed cache
/// never sees that as a change, so any widget rendering that image should
/// fold [versionOf] into its cache key / Flutter `Key`.
///
/// A process-wide in-memory map (not persisted) is enough: it only needs to
/// outlive the moment of the mutation through however long the app keeps
/// running, so every current and future widget showing that same image
/// (list thumbnails, detail pages, etc.) picks a cache key that was never
/// seen before — no manual cache eviction needed.
class ImageCacheBust {
  ImageCacheBust._();

  static final Map<String, int> _versions = {};

  static int versionOf(String key) => _versions[key] ?? 0;

  static void bump(String key) {
    _versions[key] = versionOf(key) + 1;
  }
}
