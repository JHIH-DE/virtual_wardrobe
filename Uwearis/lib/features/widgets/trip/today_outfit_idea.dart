import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/app_popup_menu.dart';
import '../common/images/refreshable_network_image.dart';
import '../common/overlays/loading_overlay.dart';

enum _OutfitCardMenuAction { regenerate, changeGarments }

/// Purely presentational — the day's outfit image, or an informational
/// empty state when there's nothing to show yet. Never triggers generation
/// itself: [TripDetailsPage] keeps that on a single bottom CTA so this card
/// and that button never compete over the same action. Once an image
/// exists, [onRegenerate]/[onChangeGarments] surface as a "⋮" menu on the
/// image instead.
class TodayOutfitIdea extends StatelessWidget {
  final VoidCallback? onTap;
  final String? imageUrl;

  /// Whether the selected day has any garments assigned at all — distinct
  /// from [imageUrl] being empty: no assignment means there's no trip plan
  /// (yet) to render, whereas an assignment with no image just hasn't been
  /// rendered yet. Each gets its own empty-state message.
  final bool hasAssignment;

  final bool isLoading;
  final String? jobStatus;
  final String? errorMessage;

  /// Shown as a "⋮" menu on top of the image — null hides that entry. Only
  /// relevant once [imageUrl] is non-empty.
  final VoidCallback? onRegenerate;
  final VoidCallback? onChangeGarments;

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
    this.onTap,
    this.imageUrl,
    this.hasAssignment = false,
    this.isLoading = false,
    this.jobStatus,
    this.errorMessage,
    this.onRegenerate,
    this.onChangeGarments,
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
            if (!isLoading &&
                (onRegenerate != null || onChangeGarments != null))
              Positioned(top: 12, right: 12, child: _buildMenuButton(l10n)),
            if (isLoading)
              LoadingOverlay(label: jobStatus ?? l10n.generatingEllipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(AppLocalizations l10n) {
    return AppPopupMenu<_OutfitCardMenuAction>(
      onSelected: (action) {
        switch (action) {
          case _OutfitCardMenuAction.regenerate:
            onRegenerate?.call();
          case _OutfitCardMenuAction.changeGarments:
            onChangeGarments?.call();
        }
      },
      items: [
        if (onRegenerate != null)
          AppPopupMenu.item(
            value: _OutfitCardMenuAction.regenerate,
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.icon),
            label: l10n.regenerateOutfit,
          ),
        if (onChangeGarments != null)
          AppPopupMenu.item(
            value: _OutfitCardMenuAction.changeGarments,
            icon: const Icon(
              Icons.checkroom_outlined,
              size: 20,
              color: AppColors.icon,
            ),
            label: l10n.changeGarments,
          ),
      ],
      trigger: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceTranslucent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.shadowSoft, blurRadius: 4)],
        ),
        child: const Icon(Icons.more_vert, size: 18, color: AppColors.icon),
      ),
    );
  }

  /// No outfit image yet — loading, an error, or one of two informational
  /// messages depending on [hasAssignment]. No action button in any case;
  /// the bottom CTA is the only way to trigger generation.
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
                  : (hasAssignment
                        ? _buildNoImageView(l10n)
                        : _buildNoAssignmentView(l10n)),
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
    ],
  );

  Widget _buildNoImageView(AppLocalizations l10n) => Text(
    l10n.noOutfitImageYet,
    style: AppTextStyle.medium16.copyWith(color: AppColors.textSecondary),
  );

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
