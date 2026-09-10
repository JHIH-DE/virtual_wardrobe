import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../common/cards/share_card_scaffold.dart';

/// A fixed-size editorial "outfit card" for rasterizing into a shareable
/// image (see `showOutfitShareSheet`): a large edge-to-edge photo, then the
/// outfit name, a compact style / season line, a clean strip of garment
/// thumbnails, and a small Uwearis signature.
///
/// Not a page component — rendered inside a `RepaintBoundary` and captured to
/// PNG at a fixed size, so different outfits always produce the same
/// dimensions.
class OutfitShareCard extends StatelessWidget {
  final ImageProvider image;
  final List<ImageProvider> garmentImages;
  final String name;

  /// Already display-formatted; the card shows the first two.
  final List<String> styles;
  final List<String> seasons;

  const OutfitShareCard({
    super.key,
    required this.image,
    required this.garmentImages,
    required this.name,
    required this.styles,
    required this.seasons,
  });

  static const double width = 320;
  static const double height = 610;

  static const int _maxStyles = 2;
  static const int _maxSeasons = 2;
  static const int _maxThumbs = 6;
  static const double _thumbWidth = 36;
  static const double _thumbHeight = 44;

  @override
  Widget build(BuildContext context) {
    final styleLine = styles.take(_maxStyles).join('   ·   ');
    final seasonLine = seasons.take(_maxSeasons).join('  /  ');
    final thumbs = garmentImages.take(_maxThumbs).toList();

    return ShareCardScaffold(
      width: width,
      height: height,
      // A try-on render is a lifestyle photo — bleed it to the edges,
      // BoxFit.cover so its own aspect never matters.
      image: Image(image: image, fit: BoxFit.cover),
      info: [
        Text(
          name,
          style: AppTextStyle.bold18,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (styleLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          shareCardShrinkLine(
            styleLine.toUpperCase(),
            AppTextStyle.bold12.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.4,
            ),
          ),
        ],
        if (seasonLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          shareCardShrinkLine(
            seasonLine,
            AppTextStyle.regular12.copyWith(color: AppColors.hintText),
          ),
        ],
        if (thumbs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < thumbs.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _Thumb(image: thumbs[i]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final ImageProvider image;

  const _Thumb({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: OutfitShareCard._thumbWidth,
      height: OutfitShareCard._thumbHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Image(image: image, fit: BoxFit.contain),
      ),
    );
  }
}
