import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../buttons/accent_pill_button.dart';
import '../images/refreshable_network_image.dart';
import '../overlays/loading_overlay.dart';
import 'card_corner_badge.dart';

/// An AI-generated image, or an empty state with a Generate action.
/// Presentational only — the caller owns the generate/regenerate calls.
class GeneratedImageCard extends StatelessWidget {
  final String? imageUrl;

  /// Whether there's anything to generate from (e.g. a trip day with an
  /// outfit). Without it there's nothing to render; with it but no
  /// [imageUrl], it just hasn't been rendered yet.
  final bool hasAssignment;

  final bool isLoading;
  final String? jobStatus;

  /// Corner badge on the image; null hides it.
  final VoidCallback? onRegenerate;

  /// Button shown when [hasAssignment] but no image yet; null shows
  /// [noImageMessage] instead.
  final VoidCallback? onGenerate;

  /// Required whenever [onGenerate] is non-null.
  final String? generateLabel;

  /// False greys the [onGenerate] button out rather than hiding it.
  final bool generateEnabled;

  /// Shown above the button while [generateEnabled] is false.
  final String? generateDisabledMessage;

  /// Shown under the broken-image icon if [imageUrl] fails to load.
  final String? errorLabel;

  /// Shown when [hasAssignment] is true but [onGenerate] is null.
  final String? noImageMessage;

  /// Shown when [hasAssignment] is false.
  final String? noAssignmentTitle;
  final String? noAssignmentHint;

  /// See [RefreshableNetworkImage.onRefreshUrl].
  final Future<String?> Function()? onRefreshUrl;

  /// Stable cache key (e.g. the try-on job id): [imageUrl] is re-signed on
  /// every fetch, so the disk cache would never hit without it.
  final String? cacheKey;

  /// Cover suits trip outfit renders (fixed portrait ratio); pass
  /// [BoxFit.contain] for photos of arbitrary ratio so nothing is cropped.
  final BoxFit imageFit;
  final Alignment imageAlignment;

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

  /// Keeps the old image under the overlay while regenerating, so a failed
  /// regenerate leaves it in place.
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
                icon: Icons.refresh,
                backgroundColor: AppColors.surfaceTranslucent,
                iconColor: AppColors.hintText,
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: const [],
                size: 36,
                iconSize: 20,
                discAlignment: Alignment.topRight,
                onTap: onRegenerate,
              ),
            ),
          if (isLoading) LoadingOverlay(label: jobStatus ?? ''),
        ],
      ),
    );
  }

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
    return AccentPillButton(
      label: generateLabel!,
      icon: Icons.auto_awesome,
      enabled: generateEnabled,
      disabledMessage: generateDisabledMessage,
      onPressed: onGenerate,
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
