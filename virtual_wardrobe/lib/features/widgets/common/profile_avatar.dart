import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';

class ProfileAvatar extends StatelessWidget {
  final ImageProvider? image;
  final VoidCallback? onTap;
  final double size;
  final bool showEditLabel;
  final double fallbackIconSize;

  const ProfileAvatar({
    super.key,
    this.image,
    this.onTap,
    this.size = 120,
    this.showEditLabel = true,
    this.fallbackIconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
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
              image != null
                  ? Image(image: image!, fit: BoxFit.cover)
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
                    color: Colors.black.withValues(alpha: 0.54),
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
