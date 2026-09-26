/// Tracks a bump counter per stable image identity (e.g. `outfit-job-{id}`),
/// for images a backend endpoint can overwrite in place at their existing
/// URL (see `OutfitService.regenerateOutfit`) — a plain URL-keyed cache
/// never sees that as a change, so any widget rendering that image should
/// fold [versionOf] into its cache key / Flutter `Key`.
///
/// A process-wide in-memory map (not persisted) is enough to make every
/// current and future widget showing that same image (list thumbnails,
/// detail pages, etc.) agree on one cache key for the lifetime of this
/// mutation — but the resulting *string* still lands in `CachedNetworkImage`'s
/// on-disk cache (via [RefreshableNetworkImage.cacheKey]/[AppImage.cacheKey]),
/// which does survive a restart. Seeding an unseen key with the current time
/// instead of 0 means this process's first version for that key can never
/// collide with whatever string an *earlier* process already wrote to that
/// disk cache for the same key at some lower counter value — real-world time
/// only moves forward, so every fresh process starts strictly past any
/// count a previous one could have reached. Starting at a plain 0 every
/// restart would otherwise resurrect a stale disk-cached image the moment a
/// photo had been re-uploaded in a prior session and the app relaunched.
class ImageCacheBust {
  ImageCacheBust._();

  static final Map<String, int> _versions = {};

  static int versionOf(String key) =>
      _versions[key] ??= DateTime.now().millisecondsSinceEpoch;

  static void bump(String key) {
    _versions[key] = versionOf(key) + 1;
  }
}
