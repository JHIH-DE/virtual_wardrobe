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

  const OutfitGrid({
    super.key,
    required this.outfits,
    required this.onRefresh,
    required this.onOutfitTap,
    required this.emptyMessage,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    if (outfits.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyStatePlaceholder(message: emptyMessage),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: GridView.builder(
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
          return OutfitCard(outfit: outfit, onTap: () => onOutfitTap(outfit));
        },
      ),
    );
  }
}
