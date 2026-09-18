import 'package:flutter/material.dart';

import 'refreshable_network_image.dart';

/// Opens [imageUrl] full-screen over a black backdrop, scaled ([BoxFit.cover])
/// so its height matches the screen's as closely as possible — an outfit
/// photo's own aspect ratio is wider than a typical phone screen's, so this
/// crops the sides rather than letterboxing top/bottom the way
/// [BoxFit.contain] would. Pinch to zoom/pan further in on top of that, via
/// an [InteractiveViewer] wrapping the image (same `minScale`/`maxScale`
/// convention as `image_editor_page.dart`'s own pinch-crop). Tapping
/// anywhere closes it and returns to the page that opened it — the one
/// canonical "tap a photo to view it full-screen, tap again to go back"
/// flow; reuse this rather than a page-local lightbox.
Future<void> showFullscreenImage(
  BuildContext context, {
  required String imageUrl,
  String? cacheKey,
  Future<String?> Function()? onRefreshUrl,
}) {
  return Navigator.push(
    context,
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => _FullscreenImagePage(
        imageUrl: imageUrl,
        cacheKey: cacheKey,
        onRefreshUrl: onRefreshUrl,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullscreenImagePage extends StatelessWidget {
  const _FullscreenImagePage({
    required this.imageUrl,
    required this.cacheKey,
    required this.onRefreshUrl,
  });

  final String imageUrl;
  final String? cacheKey;
  final Future<String?> Function()? onRefreshUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: SizedBox.expand(
            child: RefreshableNetworkImage(
              imageUrl: imageUrl,
              cacheKey: cacheKey,
              fit: BoxFit.cover,
              onRefreshUrl: onRefreshUrl,
            ),
          ),
        ),
      ),
    );
  }
}
