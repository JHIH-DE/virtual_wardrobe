import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../data/outfit.dart';
import '../common/overlays/empty_state_placeholder.dart';
import 'outfit_card.dart';

/// The pull-to-refresh 2-column [OutfitCard] grid shared by the Outfits tab,
/// the "used in outfits" list, and the outfit pickers — same delegate, same
/// empty state, only the refresh callback / tap target / empty copy differ.
class OutfitGrid extends StatelessWidget {
  final List<Outfit> outfits;
  final Future<void> Function() onRefresh;
  final void Function(Outfit) onOutfitTap;
  final String emptyMessage;
  final EdgeInsets padding;

  // The full icon+title+action empty-state treatment (see
  // [EmptyStatePlaceholder]) — all optional and additive. Left unset (as
  // every caller but the Outfits tab does), the empty state renders exactly
  // as it always has: a plain centered [emptyMessage].
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptyActionLabel;
  final IconData emptyActionIcon;
  final VoidCallback? onEmptyAction;

  // Only the Outfits tab (a main tab, whose MainNavBar floats over its
  // Scaffold.body — see EmptyStatePlaceholder.bottomInset's doc) passes
  // this; the picker/"used in..." callers leave it at 0 (their own pushed
  // Scaffold has no such overlay to clear).
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
