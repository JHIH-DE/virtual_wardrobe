import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
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
            // Sits on a plain card, not a photo — so it's near-opaque with a
            // hairline edge instead of a drop shadow, and the empty-heart
            // state is muted (a grid of unfavourited garments shouldn't read
            // as a column of hard black hearts).
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            backgroundColor: AppColors.surfaceTranslucent,
            iconColor: isFavorite ? AppColors.favorite : AppColors.hintText,
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [],
            size: 36,
            iconSize: 20,
            discAlignment: Alignment.topRight,
            onTap: onToggle,
          ),
        ),
      ],
    );
  }
}
