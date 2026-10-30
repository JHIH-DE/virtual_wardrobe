import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Shared white-card chrome (radius, padding, resting shadow), with an
/// optional header ([title], [subtitle], [trailing]) above [child].
class AppCardShell extends StatelessWidget {
  final Widget? child;
  final String? title;
  final String? subtitle;

  /// Sits to the right of [title] / [subtitle], vertically centered.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  final double blurRadius;

  /// [Clip.antiAlias] when [child] paints its own background to the edge.
  final Clip clipBehavior;

  const AppCardShell({
    super.key,
    this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
    this.blurRadius = 8,
    this.clipBehavior = Clip.none,
  }) : assert(child != null || title != null);

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
      child: title == null ? child : _buildWithHeader(),
    );
  }

  Widget _buildWithHeader() {
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    final child = this.child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title!, style: AppTextStyle.bold18.copyWith(height: 1)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: AppTextStyle.regular14.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ],
        ),
        if (child != null) ...[
          const SizedBox(height: AppDimens.cardHeaderGap),
          child,
        ],
      ],
    );
  }
}
