import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/images/refreshable_network_image.dart';
import '../common/overlays/loading_overlay.dart';

class TodayOutfitIdea extends StatelessWidget {
  final VoidCallback onGenerate;
  final VoidCallback? onTap;
  final String? imageUrl;
  final bool isLoading;
  final String? jobStatus;
  final String? errorMessage;

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
    required this.onGenerate,
    this.onTap,
    this.imageUrl,
    this.isLoading = false,
    this.jobStatus,
    this.errorMessage,
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
  /// while regenerating — rather than blanking it out, the same way Outfit
  /// Details overlays a loading state on an outfit's existing image instead
  /// of hiding it.
  Widget _buildImage(AppLocalizations l10n) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AspectRatio(
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
            if (isLoading)
              LoadingOverlay(label: jobStatus ?? l10n.generatingEllipsis),
          ],
        ),
      ),
    );
  }

  /// No outfit image yet — loading (first-ever generate), an error, or the
  /// "tap to generate" prompt.
  Widget _buildEmptyState(AppLocalizations l10n) {
    return SizedBox(
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!isLoading)
            Center(
              child: errorMessage != null
                  ? _buildErrorView(l10n)
                  : _buildGenerateView(l10n),
            ),
          if (isLoading) LoadingOverlay(label: jobStatus ?? l10n.loading),
        ],
      ),
    );
  }

  Widget _buildErrorView(AppLocalizations l10n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline, size: 32, color: AppColors.icon),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: AppTextStyle.regular13.copyWith(color: AppColors.textPrimary),
        ),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: onGenerate,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(l10n.tryAgain),
      ),
    ],
  );

  Widget _buildGenerateView(AppLocalizations l10n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l10n.noOutfitImageYet,
        style: AppTextStyle.medium16.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onGenerate,
        icon: const Icon(
          Icons.brush_rounded,
          size: 20,
          color: AppColors.textOnPrimary,
        ),
        label: Text(
          l10n.generateOutfit,
          style: AppTextStyle.bold16.copyWith(color: AppColors.textOnPrimary),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ],
  );
}
