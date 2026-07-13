import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class GarmentImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  /// Stable identity for this image's cache entry — use something that
  /// only changes when the underlying photo does (e.g. the garment's
  /// `objectName`), since [url] is a signed URL that rotates on every
  /// fetch and would otherwise defeat the cache.
  final String? cacheKey;

  const GarmentImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();

    Widget image;
    if (u.isEmpty) {
      image = Container(
        color: AppColors.border,
        child: const Icon(
          Icons.image_not_supported,
          color: AppColors.textSecondary,
        ),
      );
    } else if (u.startsWith('http')) {
      // An empty cacheKey (e.g. a garment whose objectName wasn't
      // populated by the backend) must not be passed through as-is —
      // cached_network_image would then treat every such image as the
      // same cache entry, showing one garment's photo for all of them.
      final effectiveCacheKey = (cacheKey != null && cacheKey!.isNotEmpty)
          ? cacheKey
          : null;
      image = CachedNetworkImage(
        imageUrl: u,
        cacheKey: effectiveCacheKey,
        width: width,
        height: height,
        fit: fit,
        errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: AppColors.textSecondary),
        ),
      );
    } else if (u.startsWith('file://')) {
      image = Image.file(
        File.fromUri(Uri.parse(u)),
        width: width,
        height: height,
        fit: fit,
      );
    } else {
      image = Image.file(File(u), width: width, height: height, fit: fit);
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }
    return image;
  }
}
