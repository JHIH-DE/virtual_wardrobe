import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';

/// The 2-column, fixed-row-height grid every full garment grid in the app
/// shares (My Closet, the Add Outfit slot pickers, Trip suitcase, Trip
/// garment selection). Only owns the delegate + padding + scroll behaviour;
/// each caller supplies its own item via [itemBuilder] (so per-screen
/// wrappers — [FavoriteCard], [RemovableCard], selection state, AI badges —
/// stay at the call site) and its own empty state / pull-to-refresh.
///
/// For a screen that needs a raw `SliverGrid` inside a `CustomScrollView`,
/// use [gridDelegate] directly rather than this widget.
class GarmentGrid extends StatelessWidget {
  /// The shared 2-column delegate — row height locked to
  /// [AppDimens.garmentCardHeight] so every garment card lays out identically
  /// regardless of which screen it's on.
  static const SliverGridDelegateWithFixedCrossAxisCount gridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimens.cardSpacing,
        mainAxisSpacing: AppDimens.cardSpacing,
        mainAxisExtent: AppDimens.garmentCardHeight,
      );

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry padding;

  /// When false the grid shrink-wraps and doesn't scroll itself — for
  /// embedding one grid per section inside an outer scroll view.
  final bool scrollable;

  const GarmentGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = AppDimens.pageGridPadding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
