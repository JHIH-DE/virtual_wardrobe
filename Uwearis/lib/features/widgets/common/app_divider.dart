import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';

/// A hairline divider with its vertical spacing baked in, so the gap above
/// and below is always defined by one value and can't drift apart the way
/// bare `Divider(height: ...)` + ad hoc `SizedBox`/`Padding` combinations
/// tend to (see e.g. garment_details_page.dart's Used in Outfits tile,
/// which used to double up on spacing this way).
class AppDivider extends StatelessWidget {
  final double spacing;
  final double? topSpacing;
  final double? bottomSpacing;
  final Color color;

  const AppDivider({
    super.key,
    this.spacing = AppDimens.cardHeaderGap,
    this.topSpacing,
    this.bottomSpacing,
    this.color = AppColors.borderSubtle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: topSpacing ?? spacing,
        bottom: bottomSpacing ?? spacing,
      ),
      child: Divider(height: 1, thickness: 1, color: color),
    );
  }
}
