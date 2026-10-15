import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'refreshable_network_image.dart';

/// One photo from a local path, `file://` URI or http(s) URL; the network
/// case goes through [RefreshableNetworkImage]. Pass a stable [cacheKey]
/// so a re-signed URL for the same photo still hits the disk cache.
class AppImage extends StatelessWidget {
  final String? url;
  final String? cacheKey;
  final Future<String?> Function()? onRefreshUrl;

  /// Network URLs only.
  final void Function(String oldUrl, String newUrl)? onUrlRefreshed;

  /// Network URLs only.
  final VoidCallback? onLoadError;
  final double? width;
  final double? height;

  /// Decode size in physical pixels; null decodes at full resolution.
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

  // Only one decode dimension: given both, the image is decoded to that
  // exact box and squished if the aspect ratio differs.
  int? get _decodeWidth => memCacheWidth;
  int? get _decodeHeight => memCacheWidth == null ? memCacheHeight : null;

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
        memCacheWidth: _decodeWidth,
        memCacheHeight: _decodeHeight,
        fit: fit,
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
        cacheWidth: _decodeWidth,
        cacheHeight: _decodeHeight,
        fit: fit,
      );
    } else {
      image = Image.file(
        File(u),
        width: width,
        height: height,
        cacheWidth: _decodeWidth,
        cacheHeight: _decodeHeight,
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
