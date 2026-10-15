import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../data/outfit.dart';
import '../common/overlays/empty_state_placeholder.dart';
import 'outfit_card.dart';

/// Pull-to-refresh 2-column [OutfitCard] grid.
class OutfitGrid extends StatelessWidget {
  final List<Outfit> outfits;
  final Future<void> Function() onRefresh;
  final void Function(Outfit) onOutfitTap;
  final String emptyMessage;
  final EdgeInsets padding;

  // Optional [EmptyStatePlaceholder] extras; unset shows just [emptyMessage].
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptyActionLabel;
  final IconData emptyActionIcon;
  final VoidCallback? onEmptyAction;

  // Clears the floating MainNavBar on a main tab.
  final double emptyBottomInset;

  const OutfitGrid({
    super.key,
    required this.outfits,
    required this.onRefresh,
    required this.onOutfitTap,
    required this.emptyMessage,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.emptyIcon,
    this.emptyTitle,
    this.emptyActionLabel,
    this.emptyActionIcon = Icons.add,
    this.onEmptyAction,
    this.emptyBottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: outfits.isEmpty
          ? EmptyStatePlaceholder(
              message: emptyMessage,
              icon: emptyIcon,
              title: emptyTitle,
              actionLabel: emptyActionLabel,
              actionIcon: emptyActionIcon,
              onAction: onEmptyAction,
              fillAvailableSpace: true,
              bottomInset: emptyBottomInset,
            )
          : GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppDimens.cardSpacing,
                mainAxisSpacing: AppDimens.cardSpacing,
                mainAxisExtent: AppDimens.outfitCardHeight,
              ),
              itemCount: outfits.length,
              itemBuilder: (context, index) {
                final outfit = outfits[index];
                return OutfitCard(
                  outfit: outfit,
                  onTap: () => onOutfitTap(outfit),
                );
              },
            ),
    );
  }
}
