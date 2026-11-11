import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../buttons/circle_icon_button.dart';
import '../section_header.dart';

/// Shared white-card chrome (radius, padding, resting shadow), with an
/// optional header ([title], [subtitle], [trailing]) above [child].
///
/// A card-level icon action ([actionIcon] — info, more, edit) is always the
/// glass-disc [CircleIconButton] pinned 12 from the card's top and right
/// edges, like `TripCard`'s "⋮". Pass it here rather than as [trailing].
class AppCardShell extends StatelessWidget {
  final Widget? child;
  final String? title;
  final String? subtitle;

  /// Sits to the right of [title] / [subtitle], vertically centered.
  final Widget? trailing;

  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? actionTooltip;

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
    this.actionIcon,
    this.onAction,
    this.actionTooltip,
    this.padding = const EdgeInsets.all(14),
    this.blurRadius = 8,
    this.clipBehavior = Clip.none,
  }) : assert(child != null || title != null),
       assert(
         actionIcon == null || trailing == null,
         'A card has either an icon action or a trailing widget',
       );

  /// Disc inset from the card's top and right edges.
  static const _actionInset = 12.0;
  static const _actionDiscSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final actionIcon = this.actionIcon;
    final content = title == null ? child! : _buildWithHeader(actionIcon);
    return Container(
      width: double.infinity,
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
      child: actionIcon == null
          ? Padding(padding: padding, child: content)
          : Stack(
              children: [
                Padding(padding: padding, child: content),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: _actionInset,
                      right: _actionInset,
                    ),
                    child: CircleIconButton(
                      icon: actionIcon,
                      onPressed: onAction,
                      tooltip: actionTooltip,
                      size: _actionDiscSize,
                      discAlignment: Alignment.topRight,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWithHeader(IconData? actionIcon) {
    final trailing = this.trailing;
    final child = this.child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(title: title!, subtitle: subtitle),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
            if (actionIcon != null)
              Builder(
                builder: (context) {
                  final right = padding
                      .resolve(Directionality.of(context))
                      .right;
                  return SizedBox(
                    width: math.max(
                      0,
                      _actionInset + _actionDiscSize + 8 - right,
                    ),
                  );
                },
              ),
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
