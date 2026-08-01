import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';

class TodayOutfitIdea extends StatelessWidget {
  final VoidCallback onGenerate;
  final VoidCallback? onTap;
  final String? imageUrl;
  final bool isLoading;
  final String? jobStatus;
  final String? errorMessage;

  const TodayOutfitIdea({
    super.key,
    required this.onGenerate,
    this.onTap,
    this.imageUrl,
    this.isLoading = false,
    this.jobStatus,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: hasImage
          ? GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) =>
                        Center(child: _buildPlaceholder(l10n)),
                  ),
                ),
              ),
            )
          : SizedBox(
              height: 240,
              child: Center(
                child: isLoading
                    ? _buildLoadingView(l10n)
                    : errorMessage != null
                    ? _buildErrorView(l10n)
                    : _buildGenerateView(l10n),
              ),
            ),
    );
  }

  Widget _buildLoadingView(AppLocalizations l10n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(
        jobStatus ?? l10n.loading,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _buildErrorView(AppLocalizations l10n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline, size: 48, color: AppColors.icon),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      const SizedBox(height: 16),
      TextButton(onPressed: onGenerate, child: Text(l10n.tryAgain)),
    ],
  );

  Widget _buildPlaceholder(AppLocalizations l10n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.inventory_2_outlined,
        size: 64,
        color: AppColors.icon.withValues(alpha: 0.3),
      ),
      const SizedBox(height: 16),
      Text(
        l10n.generatingLookEllipsis,
        style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _buildGenerateView(AppLocalizations l10n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.auto_awesome,
        size: 64,
        color: AppColors.icon.withValues(alpha: 0.5),
      ),
      const SizedBox(height: 16),
      Text(
        l10n.noLookImageYet,
        style: AppTextStyle.dialogBody.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onGenerate,
        icon: const Icon(
          Icons.brush_rounded,
          size: 20,
          color: AppColors.textOnPrimary,
        ),
        label: Text(
          l10n.generateLook,
          style: AppTextStyle.bold16.copyWith(color: AppColors.textOnPrimary),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ],
  );
}
