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
