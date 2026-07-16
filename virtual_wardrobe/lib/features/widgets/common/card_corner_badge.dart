import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Small circular icon badge (with shadow) meant to sit in the corner of a
/// card via [Positioned] — e.g. a remove or "suggested" marker.
class CardCornerBadge extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const CardCornerBadge({
    super.key,
    required this.icon,
    this.backgroundColor = AppColors.surface,
    this.iconColor = AppColors.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 14, color: iconColor),
      ),
    );
  }
}
