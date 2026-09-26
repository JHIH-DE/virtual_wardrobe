import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'refreshable_network_image.dart';

/// Canonical "one photo, from whichever source the app actually has it in"
/// widget — a local file path, a `file://` URI, or an http(s) URL — with
/// disk caching and signed-URL-refresh-on-expiry for the network case (via
/// [RefreshableNetworkImage]). This is the shared rendering behind
/// [GarmentImage] (garment photos) and My Virtual Model's face/body reference
/// photos; reach for this directly for a new "one photo from a mixed
/// local/remote source" case rather than copying the branching here a
/// second time. [cacheKey]/[onRefreshUrl] are plain pass-throughs to
/// [RefreshableNetworkImage] — a caller with a stable per-entity identity
/// (a garment id, a fixed "this user's face reference" key, ...) should
/// build those the same way [GarmentImage] does, so a re-signed URL for the
/// same underlying photo doesn't read as a disk-cache miss.
class AppImage extends StatelessWidget {
  final String? url;
  final String? cacheKey;
  final Future<String?> Function()? onRefreshUrl;

  /// See [RefreshableNetworkImage.onUrlRefreshed] — only fires for the
  /// network-URL case below.
  final void Function(String oldUrl, String newUrl)? onUrlRefreshed;

  /// See [RefreshableNetworkImage.onLoadError] — only fires for the
  /// network-URL case below; a local file source has no equivalent failure
  /// signal today.
  final VoidCallback? onLoadError;
  final double? width;
  final double? height;

  /// Decode target size in physical pixels — see
  /// [RefreshableNetworkImage.memCacheWidth]. Leave null for full-resolution
  /// decoding.
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BoxFit fit;
  final double borderRadius;

  const AppImage({
    super.key,
    required this.url,
    this.cacheKey,
    this.onRefreshUrl,
    this.onUrlRefreshed,
    this.onLoadError,
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
        onRefreshUrl: onRefreshUrl,
        onUrlRefreshed: onUrlRefreshed,
        onLoadError: onLoadError,
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
