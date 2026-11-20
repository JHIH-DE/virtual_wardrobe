import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/signed_url.dart';
import '../../../data/closet_analysis.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/app_divider.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/section_title.dart';
import 'garment_image.dart';
import 'garment_outfit_ideas_card.dart';

/// Versatility level, outfit ideas and similar garments. The prompt/error
/// states are fallbacks — the sheet normally opens into a loading overlay.
class ClosetMatchSheetContent extends StatelessWidget {
  final ClosetAnalysis? analysis;
  final String? errorMessage;
  final VoidCallback onAnalyze;
  final void Function(int garmentId) onGarmentTap;

  /// Each idea's "Try It On" button; null hides it.
  final void Function(List<ClosetAnalysisGarment> garments)? onCreateOutfit;

  final void Function(int garmentId, String freshUrl) onGarmentImageRefreshed;

  /// Add mode's local photo — the preview target has no image URL.
  final String? targetImageOverride;

  /// A garment's current image URL, for a thumbnail whose signed URL has
  /// already expired. A failure leaves the stale URL showing.
  final Future<String?> Function(int garmentId) loadFreshImageUrl;

  const ClosetMatchSheetContent({
    super.key,
    required this.analysis,
    required this.errorMessage,
    required this.onAnalyze,
    required this.onGarmentTap,
    this.onCreateOutfit,
    required this.onGarmentImageRefreshed,
    this.targetImageOverride,
    required this.loadFreshImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (errorMessage != null) return _buildError(l10n, errorMessage!);
    if (analysis == null) return _buildPrompt(l10n);
    return _buildResult(context, l10n, analysis!);
  }

  Widget _buildPrompt(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.versatilityDescription, style: AppTextStyle.insightCardBody),
        const SizedBox(height: 8),
        Align(
          child: AccentPillButton(
            label: l10n.analyzeWithAi,
            onPressed: onAnalyze,
          ),
        ),
      ],
    );
  }

  Widget _buildError(AppLocalizations l10n, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppTextStyle.regular14.copyWith(color: AppColors.error),
        ),
        const SizedBox(height: 8),
        Align(
          child: AccentPillButton(
            label: l10n.analyzeAgain,
            onPressed: onAnalyze,
          ),
        ),
      ],
    );
  }

  Widget _buildResult(
    BuildContext context,
    AppLocalizations l10n,
    ClosetAnalysis analysis,
  ) {
    final ideas = analysis.outfitIdeas;
    final similar = analysis.similarGarments;
    final headingStyle = AppTextStyle.bold16.copyWith(
      color: AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVersatilitySection(context, l10n, analysis.versatility),
        // Empty when the closet can't support them — omit the section.
        if (ideas.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionTitle(l10n.outfitIdeasHeading, style: headingStyle),
          const SizedBox(height: 10),
          for (var i = 0; i < ideas.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.cardSpacing),
            GarmentOutfitIdeasCard(
              title: l10n.outfitIdeaNumber(i + 1),
              onTryOn: switch (onCreateOutfit) {
                final onCreate? => () => onCreate(ideas[i].garments),
                null => null,
              },
              child: _buildGarmentThumbRow(
                ideas[i].garments,
                isOutfit: true,
                onGarmentTap: onGarmentTap,
                targetImageOverride: targetImageOverride,
                onImageUrlRefreshed: onGarmentImageRefreshed,
              ),
            ),
          ],
        ],
        if (similar.isNotEmpty) ...[
          const AppDivider(topSpacing: 20, bottomSpacing: 16),
          SectionTitle(l10n.similarInClosetHeading, style: headingStyle),
          const SizedBox(height: 10),
          _buildGarmentThumbRow(
            similar,
            onGarmentTap: onGarmentTap,
            targetImageOverride: targetImageOverride,
            onImageUrlRefreshed: onGarmentImageRefreshed,
          ),
        ],
      ],
    );
  }

  Widget _buildVersatilitySection(
    BuildContext context,
    AppLocalizations l10n,
    ClosetAnalysisVersatility versatility,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${versatility.level}',
                    style: AppTextStyle.bold24.copyWith(
                      fontSize: 52,
                      height: 1,
                      color: AppColors.accent,
                    ),
                  ),
                  TextSpan(
                    text: '/${_VersatilityLevelBar.segments}',
                    style: AppTextStyle.bold24.copyWith(
                      fontSize: 34,
                      height: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.borderSubtle,
            ),
            Expanded(
              child: Text(
                versatility.label.localizedLabel(context),
                style: AppTextStyle.bold20.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _VersatilityLevelBar(level: versatility.level),
      ],
    );
  }

  /// [isOutfit]: "+" separators and no borders except the target's.
  Widget _buildGarmentThumbRow(
    List<ClosetAnalysisGarment> garments, {
    bool isOutfit = false,
    void Function(int garmentId)? onGarmentTap,
    String? targetImageOverride,
    void Function(int garmentId, String freshUrl)? onImageUrlRefreshed,
  }) {
    return SizedBox(
      height: _AiGarmentThumb.size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: garments.length,
        separatorBuilder: (_, _) => isOutfit
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.add,
                  size: AppDimens.iconSmallSize,
                  color: AppColors.hintText,
                ),
              )
            : const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = garments[i];
          // The preview target (id 0) isn't a real garment yet.
          final canOpen = onGarmentTap != null && g.garmentId > 0;
          return _AiGarmentThumb(
            garment: g,
            bordered: !isOutfit,
            targetImageOverride: targetImageOverride,
            onTap: canOpen ? () => onGarmentTap(g.garmentId) : null,
            onImageUrlRefreshed: onImageUrlRefreshed,
            loadFreshImageUrl: loadFreshImageUrl,
          );
        },
      ),
    );
  }
}

class _VersatilityLevelBar extends StatelessWidget {
  final int level;

  const _VersatilityLevelBar({required this.level});

  static const int segments = 10;

  @override
  Widget build(BuildContext context) {
    final filled = level.clamp(0, segments);
    return Row(
      children: [
        for (var i = 0; i < segments; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < filled ? AppColors.accent : AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The target garment gets the same outline as a selected GarmentCard.
class _AiGarmentThumb extends StatefulWidget {
  final ClosetAnalysisGarment garment;
  final VoidCallback? onTap;
  final bool bordered;
  final String? targetImageOverride;
  final void Function(int garmentId, String freshUrl)? onImageUrlRefreshed;
  final Future<String?> Function(int garmentId) loadFreshImageUrl;

  const _AiGarmentThumb({
    required this.garment,
    this.onTap,
    this.bordered = true,
    this.targetImageOverride,
    this.onImageUrlRefreshed,
    required this.loadFreshImageUrl,
  });

  static const double size = 70;

  @override
  State<_AiGarmentThumb> createState() => _AiGarmentThumbState();
}

class _AiGarmentThumbState extends State<_AiGarmentThumb> {
  /// Set when the cached URL is already expired: fetch a fresh one first
  /// instead of flashing the broken-image icon.
  Future<String?>? _preRefresh;

  @override
  void initState() {
    super.initState();
    _maybeStartPreRefresh();
  }

  @override
  void didUpdateWidget(covariant _AiGarmentThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.garment.imageUrl != oldWidget.garment.imageUrl) {
      _maybeStartPreRefresh();
    }
  }

  void _maybeStartPreRefresh() {
    final id = widget.garment.garmentId;
    final url = widget.garment.imageUrl;
    final knownExpired =
        id > 0 &&
        url.isNotEmpty &&
        url.startsWith('http') &&
        isSignedUrlExpired(url);
    _preRefresh = knownExpired ? _fetchFreshUrl(id, url) : null;
  }

  Future<String?> _fetchFreshUrl(int id, String staleUrl) async {
    try {
      final freshUrl = await widget.loadFreshImageUrl(id);
      if (freshUrl != null && freshUrl.isNotEmpty && freshUrl != staleUrl) {
        widget.onImageUrlRefreshed?.call(id, freshUrl);
        return freshUrl;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildImage(String? url) {
    final garment = widget.garment;
    return GarmentImage(
      url: url,
      garmentId: garment.garmentId > 0 ? garment.garmentId : null,
      cacheKey: garment.imageCacheKey,
      // Width only — pinning both forces a non-square source to decode
      // squashed into a square.
      memCacheWidth: 160,
      fit: BoxFit.contain,
      onUrlRefreshed: widget.onImageUrlRefreshed == null
          ? null
          : (_, newUrl) =>
                widget.onImageUrlRefreshed!(garment.garmentId, newUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final garment = widget.garment;
    final preRefresh = _preRefresh;
    final Widget image;
    if (preRefresh != null) {
      image = FutureBuilder<String?>(
        future: preRefresh,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          final resolved = snapshot.data;
          return _buildImage(
            resolved != null && resolved.isNotEmpty
                ? resolved
                : garment.imageUrl,
          );
        },
      );
    } else {
      image = _buildImage(
        garment.isTarget && garment.imageUrl.isEmpty
            ? widget.targetImageOverride
            : garment.imageUrl,
      );
    }
    final thumb = Container(
      width: _AiGarmentThumb.size,
      height: _AiGarmentThumb.size,
      padding: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: widget.bordered || garment.isTarget
            ? Border.all(
                color: garment.isTarget
                    ? AppColors.borderStrong
                    : AppColors.borderSubtle,
                width: garment.isTarget ? 1.5 : 1,
              )
            : null,
      ),
      child: image,
    );
    if (widget.onTap == null) return thumb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: thumb,
    );
  }
}
