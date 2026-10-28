import 'package:flutter/material.dart';

import 'refreshable_network_image.dart';

/// The app's full-screen photo viewer: pinch to zoom, tap anywhere to close.
/// [BoxFit.cover] crops an outfit photo's sides (it's wider than a phone
/// screen) rather than letterboxing it.
Future<void> showFullscreenImage(
  BuildContext context, {
  required String imageUrl,
  String? cacheKey,
  Future<String?> Function()? onRefreshUrl,
}) {
  return showFullscreenImageWidget(
    context,
    image: RefreshableNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      fit: BoxFit.cover,
      onRefreshUrl: onRefreshUrl,
    ),
  );
}

/// [showFullscreenImage] for an image that isn't a plain network URL (e.g.
/// a garment's local file in add mode). [image] fills the screen.
Future<void> showFullscreenImageWidget(
  BuildContext context, {
  required Widget image,
  Color backgroundColor = Colors.black,
}) {
  return Navigator.push(
    context,
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          _FullscreenImagePage(image: image, backgroundColor: backgroundColor),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullscreenImagePage extends StatelessWidget {
  const _FullscreenImagePage({
    required this.image,
    required this.backgroundColor,
  });

  final Widget image;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: SizedBox.expand(child: image),
        ),
      ),
    );
  }
}
