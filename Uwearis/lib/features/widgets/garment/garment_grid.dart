import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';

/// The shared garment grid: owns delegate, padding and scrolling only; items,
/// empty state and refresh stay with the caller. A raw `SliverGrid` uses
/// [gridDelegate] instead.
class GarmentGrid extends StatelessWidget {
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
