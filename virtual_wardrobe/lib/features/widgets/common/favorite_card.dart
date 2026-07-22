import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'card_corner_badge.dart';

/// Wraps [child] with a corner badge that toggles [isFavorite] via
/// [onToggle] — no confirmation step, unlike [RemovableCard].
class FavoriteCard extends StatelessWidget {
  final Widget child;
  final bool isFavorite;
  final VoidCallback onToggle;

  const FavoriteCard({
    super.key,
    required this.child,
    required this.isFavorite,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: CardCornerBadge(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            iconColor: isFavorite ? AppColors.favorite : AppColors.icon,
            onTap: onToggle,
          ),
        ),
      ],
    );
  }
}
