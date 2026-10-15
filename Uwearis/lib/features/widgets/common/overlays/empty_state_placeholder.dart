import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../buttons/accent_pill_button.dart';
import '../section_title.dart';

/// Centered "nothing here yet" message, optionally with an icon, a [title],
/// and an [AccentPillButton] call-to-action.
class EmptyStatePlaceholder extends StatelessWidget {
  final String message;
  final IconData? icon;
  final double? height;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry padding;

  /// When given, [message] renders as a smaller subtitle.
  final String? title;

  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  /// Centers across the whole (bounded-height) area and stays
  /// pull-to-refresh-friendly — for a full-tab empty state.
  final bool fillAvailableSpace;

  /// Pinned above the centered content in its own layer, so its height
  /// changing never shifts the centered content.
  final Widget? pinnedTop;

  /// Main tabs pass [AppDimens.mainNavBarClearance]: the floating nav bar
  /// doesn't shorten their body, so content would center too low.
  final double bottomInset;

  const EmptyStatePlaceholder({
    super.key,
    required this.message,
    this.icon,
    this.height,
    this.decoration,
    this.padding = EdgeInsets.zero,
    this.title,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
    this.fillAvailableSpace = false,
    this.pinnedTop,
    this.bottomInset = 0,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be given together',
       ),
       assert(
         !fillAvailableSpace || (height == null && decoration == null),
         'fillAvailableSpace already sizes/centers itself — height/decoration '
         'are for a bounded inline slot instead, not both at once',
       ),
       assert(
         pinnedTop == null || fillAvailableSpace,
         'pinnedTop only makes sense together with fillAvailableSpace',
       ),
       assert(
         bottomInset == 0 || fillAvailableSpace,
         'bottomInset only makes sense together with fillAvailableSpace',
       );

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: height,
      width: decoration != null ? double.infinity : null,
      padding: padding,
      decoration: decoration,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 64, color: AppColors.icon),
              const SizedBox(height: 16),
            ],
            if (title != null) ...[
              SectionTitle(title!),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  (title == null
                          ? AppTextStyle.regular16
                          : AppTextStyle.regular14)
                      .copyWith(color: AppColors.textSecondary),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              AccentPillButton(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );

    if (!fillAvailableSpace) return content;

    final pinned = pinnedTop;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = (constraints.maxHeight - bottomInset).clamp(
          0.0,
          double.infinity,
        );
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            // Tight: StackFit.expand can't size to an infinite maxHeight.
            constraints: BoxConstraints(
              minHeight: availableHeight,
              maxHeight: availableHeight,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: content),
                if (pinned != null)
                  Positioned(top: 0, left: 0, right: 0, child: pinned),
              ],
            ),
          ),
        );
      },
    );
  }
}
