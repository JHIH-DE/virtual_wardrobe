import 'package:flutter/material.dart';

import '../../../core/services/garment_service.dart';
import '../../../core/utils/image_cache_bust.dart';
import '../../../data/garment.dart';
import '../common/images/app_image.dart';

/// [AppImage] with a garment's stable cache key and signed-URL refresh.
class GarmentImage extends StatelessWidget {
  final String? url;

  /// When set, a load failure refetches the garment once for a freshly
  /// signed URL. Null skips the retry.
  final int? garmentId;
  final double? width;
  final double? height;

  /// Decode size in physical pixels; null decodes at full resolution.
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BoxFit fit;
  final double borderRadius;

  /// Lets a caller holding a longer-lived copy of the URL (e.g. a persisted
  /// closet analysis) fold the fresh one back in.
  final void Function(String oldUrl, String newUrl)? onUrlRefreshed;

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
    this.onUrlRefreshed,
  });

  @override
  Widget build(BuildContext context) {
    final id = garmentId;
    // Keyed by id so a re-signed URL isn't a cache miss; the version suffix
    // changes when Edit image replaces the photo in place.
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
              // The id may come from a persisted closet analysis that
              // predates the garment's deletion; without this it 404s.
              final fresh = await GarmentService().getGarment(
                id,
                includeDeleted: true,
              );
              return fresh.imageUrl;
            },
      onUrlRefreshed: onUrlRefreshed,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fit: fit,
      borderRadius: borderRadius,
    );
  }
}
