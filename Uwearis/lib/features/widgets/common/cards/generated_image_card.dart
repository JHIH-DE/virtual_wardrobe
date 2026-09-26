import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../buttons/accent_pill_button.dart';
import '../images/refreshable_network_image.dart';
import '../overlays/loading_overlay.dart';
import 'card_corner_badge.dart';

/// Purely presentational — an AI-generated image, or an informational empty
/// state (with a Generate action) when there's nothing to show yet. Never
/// triggers generation itself: the caller owns the actual generate/regenerate
/// call, this just surfaces the triggers — a corner badge on the image once
/// one exists ([onRegenerate]), a pill button in the empty state
/// ([onGenerate]). Originally Trip Details' own day-outfit card
/// (`TodayOutfitIdea`); generalized into `common/cards/` once My Virtual
/// Model's generated base model needed the same "image, or a Generate
/// button in a bordered box" shape.
class GeneratedImageCard extends StatelessWidget {
  final String? imageUrl;

  /// Whether there's an assignment/subject to generate from at all — distinct
  /// from [imageUrl] being empty: no assignment means there's nothing to
  /// render yet (e.g. a trip day with no outfit option), whereas an
  /// assignment with no image just hasn't been rendered yet. Each gets its
  /// own empty-state message.
  final bool hasAssignment;

  final bool isLoading;
  final String? jobStatus;

  /// Shown as a corner badge on top of the image once it exists — styled
  /// like OutfitDetailsPage's own on-image icons (translucent disc, hairline
  /// border, no shadow). Null hides the badge.
  final VoidCallback? onRegenerate;

  /// Kicks off a (first or repeat) render for a subject that's ready but has
  /// no image yet — shown as a button in place of the plain "no image yet"
  /// text. Null keeps the informational text.
  final VoidCallback? onGenerate;

  /// Label for the [onGenerate] button (e.g. "Generate Outfit" / "Generate").
  /// Required whenever [onGenerate] is non-null — there is no generic
  /// fallback copy, since "what this generates" is caller-specific.
  final String? generateLabel;

  /// Whether the [onGenerate] button is enabled — the button itself always
  /// shows once [onGenerate] is non-null; this only greys it out (and shows
  /// [generateDisabledMessage] above it) rather than hiding it. Ignored when
  /// [onGenerate] is null.
  final bool generateEnabled;

  /// Shown above the [onGenerate] button, centered, while [generateEnabled]
  /// is false — explains why generating isn't offered right now. Null shows
  /// no explanation.
  final String? generateDisabledMessage;

  /// Shown under the broken-image icon if [imageUrl] fails to load and gives
  /// up (see [RefreshableNetworkImage.errorLabel]). Null shows just the icon.
  final String? errorLabel;

  /// Shown in place of the plain "no image yet" text is never offered
  /// (i.e. [onGenerate] is null while [hasAssignment] is true). Null falls
  /// back to showing nothing.
  final String? noImageMessage;

  /// Shown when [hasAssignment] is false — title + subtitle explaining there
  /// is nothing to generate from yet. Both null render nothing.
  final String? noAssignmentTitle;
  final String? noAssignmentHint;

  /// Called at most once if [imageUrl] fails to load (e.g. an expired
  /// signed URL) — return a fresh URL to retry with. See
  /// [RefreshableNetworkImage.onRefreshUrl].
  final Future<String?> Function()? onRefreshUrl;

  /// Stable cache key (e.g. the try-on job id) — see
  /// [RefreshableNetworkImage.cacheKey]. [imageUrl] is a freshly re-signed
  /// URL on every fetch even for an already-generated image, so without
  /// this the disk cache would never actually hit.
  final String? cacheKey;

  /// How [imageUrl] fills its [aspectRatio] frame. Defaults to
  /// [BoxFit.cover] + top-aligned, matching a trip outfit render (always
  /// produced at a consistent portrait ratio, so cropping never loses real
  /// content). A source photo with a genuinely different aspect ratio should
  /// pass [BoxFit.contain] instead so the whole photo stays visible rather
  /// than having its top or bottom cropped away.
  final BoxFit imageFit;
  final Alignment imageAlignment;

  /// The image frame's width:height ratio. Defaults to 3:4, matching a trip
  /// outfit render.
  final double aspectRatio;

  const GeneratedImageCard({
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
    this.errorLabel,
    this.noImageMessage,
    this.noAssignmentTitle,
    this.noAssignmentHint,
    this.onRefreshUrl,
    this.cacheKey,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.topCenter,
    this.aspectRatio = 3 / 4,
  });

  @override
  Widget build(BuildContext context) {
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
        child: hasImage ? _buildImage() : _buildEmptyState(),
      ),
    );
  }

  /// Keeps the existing image visible — with a [LoadingOverlay] on top
  /// while regenerating — rather than blanking it out, so a regenerate
  /// that fails leaves the previously valid image exactly where it was.
  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RefreshableNetworkImage(
            imageUrl: imageUrl!,
            cacheKey: cacheKey,
            fit: imageFit,
            alignment: imageAlignment,
            errorIcon: Icons.inventory_2_outlined,
            errorIconSize: 64,
            errorLabel: errorLabel,
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
          if (isLoading) LoadingOverlay(label: jobStatus ?? ''),
        ],
      ),
    );
  }

  /// No image yet — one of two informational states depending on
  /// [hasAssignment]. When ready but not yet rendered, [onGenerate] (if
  /// given) turns that state into a Generate button — [generateEnabled]
  /// false greys it out and shows [generateDisabledMessage] above it, rather
  /// than hiding the button. While a render is running, the caller's own
  /// full-screen overlay typically covers this card.
  Widget _buildEmptyState() {
    return SizedBox(
      height: 140,
      child: Center(
        child: hasAssignment ? _buildNoImageView() : _buildNoAssignmentView(),
      ),
    );
  }

  Widget _buildNoImageView() {
    final onGenerate = this.onGenerate;
    if (onGenerate == null) {
      return noImageMessage == null
          ? const SizedBox.shrink()
          : Text(
              noImageMessage!,
              style: AppTextStyle.medium16.copyWith(
                color: AppColors.textSecondary,
              ),
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
          label: generateLabel!,
          icon: Icons.auto_awesome,
          enabled: generateEnabled,
          onPressed: onGenerate,
        ),
      ],
    );
  }

  Widget _buildNoAssignmentView() {
    final title = noAssignmentTitle;
    final hint = noAssignmentHint;
    if (title == null && hint == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(
              title,
              style: AppTextStyle.medium16.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          if (title != null && hint != null) const SizedBox(height: 4),
          if (hint != null)
            Text(
              hint,
              textAlign: TextAlign.center,
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
