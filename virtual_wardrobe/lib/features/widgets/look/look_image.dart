import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/look_service.dart';
import '../../../data/look.dart';
import '../common/refreshable_network_image.dart';

/// Single source of truth for "what is this look's image URL right now" —
/// mirrors GarmentImage's reliance on `GarmentService().getGarment(id)`.
/// Goes through `Look.fromJson` (not a raw map cast) so a malformed/missing
/// field degrades to `''` instead of throwing.
Future<String> fetchFreshLookImageUrl(int lookId) async {
  final data = await LookService().getLook(lookId);
  return Look.fromJson(data).imageUrl;
}

/// Renders a look's outfit image, self-healing once on load failure by
/// refetching the look from the backend for a freshly-signed URL.
class LookImage extends StatelessWidget {
  final String imageUrl;
  final int lookId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final double borderRadius;
  final String? noImageLabel;
  final String? errorLabel;
  final Widget Function(BuildContext context)? placeholderBuilder;

  const LookImage({
    super.key,
    required this.imageUrl,
    required this.lookId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = 0,
    this.noImageLabel,
    this.errorLabel,
    this.placeholderBuilder,
  });

  Widget _fallback(IconData icon, String? label) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.icon),
            if (label != null) ...[
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyle.regular12.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = imageUrl.isEmpty
        ? _fallback(Icons.image_outlined, noImageLabel)
        : RefreshableNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            placeholderBuilder: placeholderBuilder,
            errorLabel: errorLabel,
            onRefreshUrl: () => fetchFreshLookImageUrl(lookId),
          );

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }
    return image;
  }
}
