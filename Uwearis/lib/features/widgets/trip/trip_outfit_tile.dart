import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/outfit.dart';
import '../../../data/trip_outfit.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/cards/category_tag.dart';
import '../common/images/refreshable_network_image.dart';
import '../garment/garment_image.dart';

/// One outfit in Trip Details' grid (laid out with `OutfitGrid.gridDelegate`).
/// Same chrome and height as `OutfitCard`, but a trip outfit often has no
/// try-on yet, so it falls back to its garments, and it carries one status
/// tag and the missing-garment state.
class TripOutfitTile extends StatelessWidget {
  final TripOutfit outfit;

  /// 1-based position, for the fallback name of an unnamed outfit.
  final int index;
  final Set<int> suitcaseIds;
  final VoidCallback onTap;
  final Future<String?> Function()? onRefreshImageUrl;

  const TripOutfitTile({
    super.key,
    required this.outfit,
    required this.index,
    required this.suitcaseIds,
    required this.onTap,
    this.onRefreshImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMissing = outfit.missingGarments(suitcaseIds).isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.outfitCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      outfit.hasImage ? _buildImage() : _buildGarments(),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: CategoryTag(label: _tagLabel(l10n)),
                      ),
                      if (isMissing)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(
                            Icons.error,
                            size: 22,
                            color: AppColors.error,
                            semanticLabel: l10n.missingGarmentsCount(
                              outfit.missingGarments(suitcaseIds).length,
                            ),
                            shadows: [
                              Shadow(color: AppColors.surface, blurRadius: 3),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.borderSubtle),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Text(
                    _name(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bold14.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The one tag a tile has room for: Edited over Kept over the source.
  String _tagLabel(AppLocalizations l10n) {
    if (outfit.isManuallyEdited) return l10n.tripOutfitEdited;
    if (outfit.isPinned) return l10n.tripOutfitKept;
    return switch (outfit.source) {
      TripOutfitSource.savedOutfit => l10n.tripOutfitSourceSaved,
      TripOutfitSource.suggested => l10n.tripOutfitSourceSuggested,
      TripOutfitSource.manual => l10n.tripOutfitSourceManual,
    };
  }

  String _name(AppLocalizations l10n) =>
      (outfit.name?.trim().isNotEmpty ?? false)
      ? outfit.name!
      : l10n.tripOutfitFallbackName(index);

  /// Decoded at the tile's physical width (like the garment cells below): a
  /// fixed size blurs on 3x screens. A portrait render covering this
  /// landscape-ish slot scales by width.
  Widget _buildImage() {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshableNetworkImage(
        imageUrl: outfit.resultImageUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        memCacheWidth:
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil(),
        cacheKey: outfit.imageOutfitId == null
            ? null
            : outfitImageVersionedCacheKey(outfit.imageOutfitId!),
        onRefreshUrl: onRefreshImageUrl,
      ),
    );
  }

  /// Up to four garments in a 2×2 grid, until the outfit has a try-on.
  Widget _buildGarments() {
    final shown = outfit.garments.take(4).toList();
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final g in shown)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => GarmentImage(
                    url: g.imageUrl,
                    garmentId: g.id,
                    memCacheWidth:
                        (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                    fit: BoxFit.contain,
                    borderRadius: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
