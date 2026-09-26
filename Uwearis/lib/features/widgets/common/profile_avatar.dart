import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'images/app_image.dart';

class ProfileAvatar extends StatelessWidget {
  final String? url;

  /// See [AppImage.onRefreshUrl] — a re-fetch callback so a broken/expired
  /// signed URL self-heals once instead of just showing the error state.
  final Future<String?> Function()? onRefreshUrl;

  final VoidCallback? onTap;
  final double size;
  final bool showEditLabel;
  final double fallbackIconSize;

  const ProfileAvatar({
    super.key,
    this.url,
    this.onRefreshUrl,
    this.onTap,
    this.size = 120,
    this.showEditLabel = true,
    this.fallbackIconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasImage
                  ? AppImage(
                      url: url,
                      onRefreshUrl: onRefreshUrl,
                      fit: BoxFit.cover,
                    )
                  : ColoredBox(
                      color: AppColors.placeholderSurface,
                      child: Icon(
                        Icons.person,
                        size: fallbackIconSize,
                        color: AppColors.icon,
                      ),
                    ),
              if (showEditLabel)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 4, bottom: 13),
                    color: AppColors.overlayMedium,
                    child: Text(
                      AppLocalizations.of(context).editPhoto,
                      textAlign: TextAlign.center,
                      style: AppTextStyle.bold12.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
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
