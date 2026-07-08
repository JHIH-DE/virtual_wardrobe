import 'package:flutter/material.dart';

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  final Color backgroundColor;
  final double? aspectRatio;
  final BoxFit fit;

  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
    this.backgroundColor = Colors.black,
    this.aspectRatio = 0.6,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      imageUrl,
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
