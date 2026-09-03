import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// Shared white-card chrome — radius, padding, resting shadow — used by
/// page-level cards across the app (e.g. Lifestyle's schedule/comfort
/// cards, AI Model's reference/body-measurements cards) so they read as
/// one family even though their contents differ.
class AppCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Resting-shadow blur. Defaults to the app-wide 8; a few larger content
  /// cards (Style Taste) use a softer 16 — pass it explicitly there rather
  /// than hand-rolling the whole `BoxDecoration`.
  final double blurRadius;

  const AppCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.blurRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
