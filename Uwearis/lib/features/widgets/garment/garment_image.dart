import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/garment_service.dart';
import '../../../core/utils/image_cache_bust.dart';
import '../../../data/garment.dart';
import '../common/images/refreshable_network_image.dart';

class GarmentImage extends StatelessWidget {
  final String? url;

  /// When set, a load failure triggers one refetch of this garment from
  /// the backend to pick up a freshly-signed image URL (e.g. the cached one
  /// expired). Leave null to skip the retry (no ID available to refetch).
  final int? garmentId;
  final double? width;
  final double? height;

  /// Decode target size in physical pixels for thumbnail-sized uses — see
  /// [RefreshableNetworkImage.memCacheWidth]. Leave null for full-resolution
  /// decoding.
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
    final u = (url ?? '').trim();

    Widget image;
    if (u.isEmpty) {
      image = Container(
        color: AppColors.borderSubtle,
        child: const Icon(Icons.image_not_supported, color: AppColors.icon),
      );
    } else if (u.startsWith('http')) {
      final id = garmentId;
      // Same scheme as OutfitImage's cacheKey: a re-signed URL for the same
      // garment shouldn't read as a disk-cache miss, so key by the stable
      // id instead — plus ImageCacheBust's version suffix, bumped whenever
      // Edit image replaces this exact garment's photo in place (same
      // stable id, genuinely different bytes), which a stable-key cache
      // would otherwise never see as a change and keep serving stale.
      final baseKey = id != null ? garmentImageCacheKey(id) : null;
      final cacheKey = baseKey == null
          ? null
          : '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
      image = RefreshableNetworkImage(
        key: cacheKey == null ? null : ValueKey(cacheKey),
        imageUrl: u,
        cacheKey: cacheKey,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fit: fit,
        // Plain white background instead of a per-tile loading spinner —
        // quieter for dense grids/lists — with a quick cross-fade once the
        // image actually loads.
        placeholderBuilder: (_) => Container(color: AppColors.surface),
        fadeInDuration: const Duration(milliseconds: 200),
        errorIcon: Icons.broken_image,
        onRefreshUrl: id == null
            ? null
            : () async {
                final fresh = await GarmentService().getGarment(id);
                return fresh.imageUrl;
              },
      );
    } else if (u.startsWith('file://')) {
      image = Image.file(
        File.fromUri(Uri.parse(u)),
        width: width,
        height: height,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
        fit: fit,
      );
    } else {
      image = Image.file(
        File(u),
        width: width,
        height: height,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
        fit: fit,
      );
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
