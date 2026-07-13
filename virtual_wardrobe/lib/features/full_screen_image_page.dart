import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  /// Stable identity for this image's cache entry — pass the same key
  /// used elsewhere for this image (e.g. a garment's `objectName` or
  /// `'look_${id}'`) so this zoomed view reuses that cache.
  final String? cacheKey;
  final Color backgroundColor;
  final double? aspectRatio;
  final BoxFit fit;

  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.backgroundColor = Colors.black,
    this.aspectRatio = 0.6,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      fit: fit,
      alignment: Alignment.center,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: InteractiveViewer(
            clipBehavior: Clip.none,
            minScale: 0.5,
            maxScale: 4.0,
            child: Hero(
              tag: 'full_screen_image',
              child: aspectRatio != null
                  ? AspectRatio(aspectRatio: aspectRatio!, child: image)
                  : image,
            ),
          ),
        ),
      ),
    );
  }
}
