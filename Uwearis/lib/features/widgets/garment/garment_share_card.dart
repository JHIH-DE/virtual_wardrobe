import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../common/cards/share_card_scaffold.dart';

/// A fixed-size editorial "garment card" for rasterizing into a shareable
/// image (see `showGarmentShareSheet`) — same frame as [OutfitShareCard],
/// but the photo is a product shot (`contain` on white, not a bleeding
/// lifestyle render) and the meta is category / details / an optional
/// closet-match line.
///
/// [categoryLine] / [detailLine] / [matchLine] are already assembled by the
/// sheet; empty / null → the line is dropped.
class GarmentShareCard extends StatelessWidget {
  final ImageProvider image;
  final String name;
  final String categoryLine;
  final String detailLine;
  final String? matchLine;

  const GarmentShareCard({
    super.key,
    required this.image,
    required this.name,
    required this.categoryLine,
    required this.detailLine,
    this.matchLine,
  });

  static const double width = 320;
  static const double height = 520;

  static final TextStyle _metaStyle = AppTextStyle.bold12.copyWith(
    color: AppColors.textSecondary,
    letterSpacing: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return ShareCardScaffold(
      width: width,
      height: height,
      borderRadius: 0,
      // Product shots are framed on white — keep them whole (`contain`) with
      // a little breathing room rather than cropping to fill.
      image: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(18),
        child: Image(image: image, fit: BoxFit.contain),
      ),
      info: [
        Text(
          name,
          style: AppTextStyle.bold18,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Category / product type / colour + (if analysed) the closet-match
        // line — same tracked-caps treatment.
        if (categoryLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          shareCardShrinkLine(categoryLine.toUpperCase(), _metaStyle),
        ],
        if (matchLine != null) ...[
          const SizedBox(height: 4),
          shareCardShrinkLine(matchLine!.toUpperCase(), _metaStyle),
        ],
        if (detailLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          shareCardShrinkLine(
            detailLine,
            AppTextStyle.regular12.copyWith(color: AppColors.hintText),
          ),
        ],
      ],
    );
  }
}
