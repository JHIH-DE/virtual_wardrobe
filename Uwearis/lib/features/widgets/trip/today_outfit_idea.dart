import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/cards/card_corner_badge.dart';
import '../common/images/refreshable_network_image.dart';
import '../common/overlays/loading_overlay.dart';

/// Purely presentational — the day's outfit image, or an informational
/// empty state when there's nothing to show yet. Never triggers generation
/// itself directly: [TripDetailsPage] owns the actual regenerate/generate
/// calls, this just surfaces the triggers — a corner badge on the image
/// once one exists ([onRegenerate]), Change Garments in the page's own date
/// header instead.
class TodayOutfitIdea extends StatelessWidget {
  final String? imageUrl;

  /// Whether the selected day has any garments assigned at all — distinct
  /// from [imageUrl] being empty: no assignment means there's no trip plan
  /// (yet) to render, whereas an assignment with no image just hasn't been
  /// rendered yet. Each gets its own empty-state message.
  final bool hasAssignment;

  final bool isLoading;
  final String? jobStatus;

  /// Shown as a corner badge on top of the image once it exists — styled
  /// like OutfitDetailsPage's own on-image icons (translucent disc, hairline
  /// border, no shadow). Null hides the badge.
  final VoidCallback? onRegenerate;

  /// Kicks off a (first or repeat) render for a day that already has an
  /// assigned option but no image yet — shown as a button in place of the
  /// plain "no image yet" text. Null keeps the informational text.
  final VoidCallback? onGenerate;

  /// Label for the [onGenerate] button (e.g. "Generate Outfit" /
  /// "Regenerate Outfit"). Ignored when [onGenerate] is null.
  final String? generateLabel;

  /// Whether the [onGenerate] button is enabled — the button itself always
  /// shows once [onGenerate] is non-null; this only greys it out (and shows
  /// [generateDisabledMessage] above it) rather than hiding it. Ignored when
  /// [onGenerate] is null.
  final bool generateEnabled;

  /// Shown above the [onGenerate] button, centered, while [generateEnabled]
  /// is false — explains why generating isn't offered right now (e.g. an
  /// incomplete core outfit). Null shows no explanation.
  final String? generateDisabledMessage;

  /// Called at most once if [imageUrl] fails to load (e.g. an expired
  /// signed URL) — return a fresh URL to retry with. See
  /// [RefreshableNetworkImage.onRefreshUrl].
  final Future<String?> Function()? onRefreshUrl;

  /// Stable cache key (e.g. the try-on job id) — see
  /// [RefreshableNetworkImage.cacheKey]. [imageUrl] is a freshly re-signed
  /// URL on every fetch even for an already-generated outfit, so without
  /// this the disk cache would never actually hit.
  final String? cacheKey;

  const TodayOutfitIdea({
    super.key,
    this.imageUrl,
    this.hasAssignment = false,
    this.isLoading = false,
    this.jobStatus,
    this.onRegenerate,
    this.onGenerate,
    this.generateLabel,
    this.generateEnabled = true,
    this.generateDisabledMessage,
    this.onRefreshUrl,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: hasImage ? _buildImage(l10n) : _buildEmptyState(l10n),
      ),
    );
  }

  /// Keeps the existing image visible — with a [LoadingOverlay] on top
  /// while regenerating — rather than blanking it out, so a regenerate
  /// that fails leaves the previously valid image exactly where it was.
  Widget _buildImage(AppLocalizations l10n) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RefreshableNetworkImage(
            imageUrl: imageUrl!,
            cacheKey: cacheKey,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorIcon: Icons.inventory_2_outlined,
            errorIconSize: 64,
            errorLabel: l10n.generatingOutfitEllipsis,
            onRefreshUrl: onRefreshUrl,
          ),
          if (!isLoading && onRegenerate != null)
            Positioned(
              top: 12,
              right: 12,
              child: CardCornerBadge(
                // Same treatment as OutfitDetailsPage's own on-image icons
                // (its "⋮" trigger / favourite badge): translucent disc,
                // hairline border, no drop shadow.
                icon: Icons.refresh,
                backgroundColor: AppColors.surfaceTranslucent,
                iconColor: AppColors.hintText,
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: const [],
                size: 36,
                iconSize: 20,
                // Without this the disc centers inside its (larger,
                // touch-target-padded) hit box, sitting ~4px further in
                // from the top/right edge than OutfitDetailsPage's own
                // plain-Container icons at the same Positioned offset.
                discAlignment: Alignment.topRight,
                onTap: onRegenerate,
              ),
            ),
          if (isLoading)
            LoadingOverlay(label: jobStatus ?? l10n.generatingEllipsis),
        ],
      ),
    );
  }

  /// No outfit image yet — one of two informational states depending on
  /// [hasAssignment]. When the day has an option but no image, [onGenerate]
  /// (if given) turns that state into a "Generate Outfit" button —
  /// [generateEnabled] false greys it out and shows
  /// [generateDisabledMessage] above it, rather than hiding the button.
  /// While a render is running, [TripDetailsPage]'s own full-screen overlay
  /// covers this card.
  Widget _buildEmptyState(AppLocalizations l10n) {
    return SizedBox(
      height: 140,
      child: Center(
        child: hasAssignment
            ? _buildNoImageView(l10n)
            : _buildNoAssignmentView(l10n),
      ),
    );
  }

  Widget _buildNoImageView(AppLocalizations l10n) {
    final onGenerate = this.onGenerate;
    if (onGenerate == null) {
      return Text(
        l10n.noOutfitImageYet,
        style: AppTextStyle.medium16.copyWith(color: AppColors.textSecondary),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!generateEnabled && generateDisabledMessage != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              generateDisabledMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        AccentPillButton(
          label: generateLabel ?? l10n.generateOutfit,
          icon: Icons.auto_awesome,
          enabled: generateEnabled,
          onPressed: onGenerate,
        ),
      ],
    );
  }

  Widget _buildNoAssignmentView(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.noOutfitPlannedYetTitle,
          style: AppTextStyle.medium16.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.noOutfitPlannedYetHint,
          textAlign: TextAlign.center,
          style: AppTextStyle.regular13.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
