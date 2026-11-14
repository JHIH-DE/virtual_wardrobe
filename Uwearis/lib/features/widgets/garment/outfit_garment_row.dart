import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../common/adaptive_side_layout.dart';
import 'garment_image.dart';

/// A garment in an outfit being built (Create Outfit, Outfit Edit): photo,
/// name and category line, plus optional [trailing] actions. The category
/// line matches the Add Garment `AppListCard`'s subtitle size.
///
/// When the name's or subtitle's widest word no longer fits beside the
/// photo at the current text size, the photo moves above the text.
class OutfitGarmentRow extends StatelessWidget {
  static const double minHeight = 84;
  static const double thumbnailWidth = 78;
  static const EdgeInsets _textPadding = EdgeInsets.fromLTRB(10, 8, 14, 8);

  static const TextStyle _nameStyle = AppTextStyle.bold14;
  static final TextStyle _subtitleStyle = AppTextStyle.regular14.copyWith(
    color: AppColors.textSecondary,
  );

  final Garment garment;
  final String subtitle;
  final VoidCallback? onTap;

  /// Marks the photo with an error badge (the garment can't be used).
  final bool isInvalid;

  /// Beside the text, or below it once the text needs the width.
  final Widget? trailing;

  const OutfitGarmentRow({
    super.key,
    required this.garment,
    required this.subtitle,
    this.onTap,
    this.isInvalid = false,
    this.trailing,
  });

  bool _photoStacks(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final textWidth = width - thumbnailWidth - 1 - _textPadding.horizontal;
    final widest = [
      longestLatinWordWidth(garment.name, _nameStyle, scaler),
      longestLatinWordWidth(subtitle, _subtitleStyle, scaler),
    ].reduce((a, b) => a > b ? a : b);
    return widest > textWidth;
  }

  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          garment.name,
          style: _nameStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: _subtitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final textArea = Padding(
      padding: _textPadding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: trailing == null
            ? text
            : AdaptiveSideLayout(
                sideEdge: AdaptiveSide.trailing,
                gap: 8,
                stackedGap: 4,
                side: trailing!,
                content: text,
              ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_photoStacks(context, constraints.maxWidth)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: thumbnailWidth, child: _photo()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(height: 1, color: AppColors.borderSubtle),
                  ),
                  textArea,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: thumbnailWidth, child: _photo()),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(width: 1, color: AppColors.borderSubtle),
                  ),
                  Expanded(child: textArea),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _photo() => Padding(
    padding: const EdgeInsets.all(8),
    child: Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Positioned, so a tall photo doesn't stretch the row's height.
        Positioned.fill(
          child: GarmentImage(
            url: garment.imageUrl,
            garmentId: garment.id,
            cacheKey: garment.imageCacheKey,
            fit: BoxFit.contain,
          ),
        ),
        if (isInvalid)
          Positioned(
            top: -4,
            right: -4,
            child: Icon(
              Icons.error,
              size: 16,
              color: AppColors.error,
              shadows: [Shadow(color: AppColors.surface, blurRadius: 3)],
            ),
          ),
      ],
    ),
  );
}
