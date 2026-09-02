import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/outfit_service.dart';
import '../../../core/utils/image_cache_bust.dart';
import '../../../data/outfit.dart';
import '../common/images/refreshable_network_image.dart';

/// Single source of truth for "what is this outfit's image URL right now" —
/// mirrors GarmentImage's reliance on `GarmentService().getGarment(id)`.
/// Goes through `Outfit.fromJson` (not a raw map cast) so a malformed/missing
/// field degrades to `''` instead of throwing.
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
    // The backend hands back a freshly re-signed URL on every fetch even
    // when the underlying image hasn't changed, which would otherwise
    // defeat the disk cache (URL-keyed by default) on every refetch. Key by
    // the stable outfit/job id instead — same scheme as
    // trip_details_page.dart's own outfit image, so the two can even share
    // a cache entry. The version suffix comes from ImageCacheBust: this same
    // image can also be overwritten in place at this exact URL by
    // OutfitService.regenerateOutfit (see outfit_details_page.dart), which a
    // stable-URL/stable-key cache would otherwise never see as a change.
    final baseKey = outfitImageCacheKey(outfitId);
    final cacheKey = '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
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
            // Plain white background instead of a per-tile loading
            // spinner — quieter for dense grids/lists — with a quick
            // cross-fade once the image actually loads.
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
