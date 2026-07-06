import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class ProfileAvatar extends StatelessWidget {
  final ImageProvider? image;
  final VoidCallback? onTap;
  final double size;

  const ProfileAvatar({super.key, this.image, this.onTap, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              image != null
                  ? Image(image: image!, fit: BoxFit.cover)
                  : const ColoredBox(
                      color: AppColors.avatarPlaceholderBackground,
                      child: Icon(Icons.person, size: 64, color: Colors.white),
                    ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.only(top: 4, bottom: 13),
                  color: Colors.black54,
                  child: Text(
                    'Edit Photo',
                    textAlign: TextAlign.center,
                    style: AppTextStyle.bold12.copyWith(color: Colors.white),
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
