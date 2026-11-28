import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_durations.dart';
import '../../../data/magazine.dart';

/// A magazine photo from the backend. Not [AppImage]: the CMS (Flutter Web)
/// renders these widgets too, and AppImage pulls in `dart:io` and the
/// signed-in session's URL refresh.
class MagazineNetworkPhoto extends StatelessWidget {
  final MagazinePhoto? photo;
  final BoxFit fit;

  /// Where a cropped photo is anchored; null = the photo's own focal point.
  final Alignment? alignment;

  /// Shape of the placeholder while a photo sized by its own aspect ratio
  /// loads (otherwise it would load at zero height).
  final double? placeholderAspectRatio;

  const MagazineNetworkPhoto({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.alignment,
    this.placeholderAspectRatio,
  });

  Widget _blank({Widget? child}) {
    final box = ColoredBox(color: AppColors.surface, child: child);
    final ratio = placeholderAspectRatio;
    return ratio == null ? box : AspectRatio(aspectRatio: ratio, child: box);
  }

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo == null) return _blank();
    final alignment = this.alignment ?? Alignment(photo.focalX, photo.focalY);
    // Zoom and the whole-photo option only apply to a photo framed to fill
    // its box; a contained one (a product cut-out) is always shown as is.
    if (fit != BoxFit.cover) return _image(photo, alignment, fit);
    if (!photo.whole) {
      return _zoomed(photo, alignment, _image(photo, alignment, fit));
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _backdropBlur,
              sigmaY: _backdropBlur,
              tileMode: TileMode.decal,
            ),
            child: Transform.scale(
              scale: 1.1,
              child: _image(photo, alignment, BoxFit.cover),
            ),
          ),
          const ColoredBox(color: AppColors.overlaySubtle),
          _zoomed(photo, alignment, _image(photo, alignment, BoxFit.contain)),
        ],
      ),
    );
  }

  /// Behind a whole photo: blurred well past recognition, so it reads as
  /// the photo's colour rather than a second copy of it.
  static const double _backdropBlur = 28;

  Widget _zoomed(MagazinePhoto photo, Alignment alignment, Widget image) =>
      photo.zoom <= 1
      ? image
      : ClipRect(
          child: Transform.scale(
            scale: photo.zoom,
            alignment: alignment,
            child: image,
          ),
        );

  Widget _image(MagazinePhoto photo, Alignment alignment, BoxFit fit) {
    if (photo.isAsset) {
      return Image.asset(
        photo.url,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => _blank(),
      );
    }
    if (kIsWeb) {
      // The CMS: the bucket doesn't allow reading a signed image's pixels
      // cross-origin, which CachedNetworkImage needs on the web (it drew
      // nothing). Image.network falls back to an <img> element there.
      return Image.network(
        photo.url,
        fit: fit,
        alignment: alignment,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: (_, child, frame, loaded) =>
            loaded || frame != null ? child : _blank(),
        errorBuilder: (_, _, _) => _blank(
          child: const Center(
            child: Icon(Icons.broken_image, color: AppColors.icon),
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: photo.url,
      cacheKey: photo.cacheKey,
      fit: fit,
      alignment: alignment,
      fadeInDuration: AppDurations.standard,
      placeholder: (_, _) => _blank(),
      errorWidget: (_, _, _) => _blank(
        child: const Center(
          child: Icon(Icons.broken_image, color: AppColors.icon),
        ),
      ),
    );
  }
}
