import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/outfit_service.dart';
import '../../../data/outfit.dart';
import '../common/images/refreshable_network_image.dart';

/// A freshly-signed image URL for the outfit.
Future<String> fetchFreshOutfitImageUrl(int groupId, int outfitId) async {
  final outfit = await OutfitService().getOutfit(groupId, outfitId);
  return outfit.imageUrl;
}

/// Renders an outfit's image, self-healing once on load failure by
/// refetching the outfit from the backend for a freshly-signed URL.
class OutfitImage extends StatelessWidget {
  final String imageUrl;
  final int groupId;
  final int outfitId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final double borderRadius;
  final String? noImageLabel;
  final String? errorLabel;
  final Widget Function(BuildContext context)? placeholderBuilder;

  const OutfitImage({
    super.key,
    required this.imageUrl,
    required this.groupId,
    required this.outfitId,
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
    // Keyed by outfit id, not URL: every fetch re-signs the URL. The version
    // suffix catches a regenerate overwriting the image in place.
    final cacheKey = outfitImageVersionedCacheKey(outfitId);
    final image = imageUrl.isEmpty
        ? _fallback(Icons.image_outlined, noImageLabel)
        : RefreshableNetworkImage(
            key: ValueKey(cacheKey),
            imageUrl: imageUrl,
            cacheKey: cacheKey,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            placeholderBuilder:
                placeholderBuilder ??
                (_) => Container(color: AppColors.surface),
            fadeInDuration: const Duration(milliseconds: 200),
            errorLabel: errorLabel,
            onRefreshUrl: () => fetchFreshOutfitImageUrl(groupId, outfitId),
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
