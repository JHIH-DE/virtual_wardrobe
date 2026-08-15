import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'dashed_border_painter.dart';
import '../buttons/pill_button.dart';

/// Photo preview when [imageProvider] is set, otherwise a dashed-border
/// "Upload Image" placeholder with a choose-photo button.
class PhotoUploadField extends StatelessWidget {
  final ImageProvider? imageProvider;
  final VoidCallback? onTap;
  final double aspectRatio;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;

  const PhotoUploadField({
    super.key,
    required this.imageProvider,
    required this.onTap,
    this.aspectRatio = 3 / 4,
    this.title,
    this.subtitle,
    this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = imageProvider;
    if (provider != null) {
      return Center(
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Image(image: provider, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: PillButton.floating(
                  label: l10n.editImage,
                  icon: Image.asset(
                    'assets/images/edit.png',
                    height: AppDimens.iconSmallSize,
                  ),
                  onTap: onTap ?? () {},
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: DashedBorderPainter(color: AppColors.borderStrong, radius: 16),
        child: Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            color: AppColors.placeholderSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title ?? l10n.uploadImage, style: AppTextStyle.semibold16),
              const SizedBox(height: 6),
              Text(
                subtitle ?? l10n.chooseClearPhotoHint,
                style: AppTextStyle.regular13.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.upload, size: 16),
                label: Text(buttonLabel ?? l10n.choosePhoto),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.textPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
