import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// Shared white-card chrome (radius, padding, resting shadow).
class AppCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  final double blurRadius;

  /// [Clip.antiAlias] when [child] paints its own background to the edge.
  final Clip clipBehavior;

  const AppCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.blurRadius = 8,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: blurRadius,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
