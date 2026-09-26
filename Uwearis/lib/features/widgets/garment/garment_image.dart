import 'package:flutter/material.dart';

import '../../../core/services/garment_service.dart';
import '../../../core/utils/image_cache_bust.dart';
import '../../../data/garment.dart';
import '../common/images/app_image.dart';

/// Garment-specific wrapping of [AppImage]: computes the stable per-garment
/// cache key (bumped by [ImageCacheBust] whenever Edit image replaces this
/// exact garment's photo — see garment_details_page.dart) and the
/// signed-URL refresh callback; [AppImage] itself owns the actual
/// local-file/network rendering, shared with any other "one photo, mixed
/// source" screen (e.g. My Virtual Model's reference photos).
class GarmentImage extends StatelessWidget {
  final String? url;

  /// When set, a load failure triggers one refetch of this garment from
  /// the backend to pick up a freshly-signed image URL (e.g. the cached one
  /// expired). Leave null to skip the retry (no ID available to refetch).
  final int? garmentId;
  final double? width;
  final double? height;

  /// Decode target size in physical pixels for thumbnail-sized uses — see
  /// [AppImage.memCacheWidth]. Leave null for full-resolution decoding.
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BoxFit fit;
  final double borderRadius;

  const GarmentImage({
    super.key,
    required this.url,
    this.garmentId,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final id = garmentId;
    // A re-signed URL for the same garment shouldn't read as a disk-cache
    // miss, so key by the stable id instead — plus ImageCacheBust's version
    // suffix, bumped whenever Edit image replaces this exact garment's
    // photo in place (same stable id, genuinely different bytes), which a
    // stable-key cache would otherwise never see as a change and keep
    // serving stale.
    final baseKey = id != null ? garmentImageCacheKey(id) : null;
    final cacheKey = baseKey == null
        ? null
        : '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';

    return AppImage(
      url: url,
      cacheKey: cacheKey,
      onRefreshUrl: id == null
          ? null
          : () async {
              final fresh = await GarmentService().getGarment(id);
              return fresh.imageUrl;
            },
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fit: fit,
      borderRadius: borderRadius,
    );
  }
}
