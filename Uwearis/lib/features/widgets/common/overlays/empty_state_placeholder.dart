import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../buttons/accent_pill_button.dart';
import '../section_title.dart';

/// Centered "nothing here yet" message, optionally with a leading icon, a
/// background decoration (e.g. a bordered box for a compact inline slot),
/// a bold [title] headline above the message, and a trailing
/// [AccentPillButton] call-to-action — the full "start doing the thing"
/// treatment used by the main tabs' (Closet/Outfits/Trips) and Trip
/// Suitcase's own empty states. All of that is optional and additive: a
/// caller that only passes [message] (the majority — pickers, filtered
/// sub-lists, "used in..." lists) gets exactly the plain single-line
/// treatment this widget always had.
class EmptyStatePlaceholder extends StatelessWidget {
  final String message;
  final IconData? icon;
  final double? height;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry padding;

  /// Headline shown above [message]. Once given, [message] reads as a
  /// smaller secondary subtitle rather than the plain single-line message
  /// style used when there's no title.
  final String? title;

  /// A call-to-action pill below the text. [actionLabel] and [onAction] are
  /// given together, or not at all.
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  /// When true, this centers itself across the *whole* scrollable area it's
  /// placed in (typically a full tab body) rather than just within its own
  /// natural size, and stays pull-to-refresh-friendly — the one mechanism
  /// every "full empty state" on the app now shares (Closet/Outfits/Trips'
  /// empty tabs, Trip Suitcase's empty suitcase). Requires a bounded-height
  /// ancestor (a `Scaffold.body`, an `Expanded`, ... — not an unconstrained
  /// `Column`/`ListView`). Leave this false (default) for anything embedded
  /// in an already-sized inline slot instead ([height]/[decoration]).
  final bool fillAvailableSpace;

  /// Only meaningful with [fillAvailableSpace]. Content pinned to the top of
  /// that same full-body layer, independent of the centered content below —
  /// e.g. Trip Suitcase's collapsible packing-advice card. It sits in its
  /// own [Positioned] layer, so its own height changing (an expand/collapse
  /// animation, new text loading in, ...) never shifts the centered content;
  /// a plain scrolling layout can't do that, since a sibling would just push
  /// the next one down as it grows.
  final Widget? pinnedTop;

  /// Only meaningful with [fillAvailableSpace]. Extra space to leave clear
  /// at the *bottom* of the centering area — for the main tabs
  /// (Closet/Outfits/Trips), pass [AppDimens.mainNavBarClearance]. Their
  /// `Scaffold.body` isn't actually shortened for `MainNavBar` (it's a
  /// floating overlay painted on top by `MainShell`, not a
  /// `bottomNavigationBar`), so without this the content centers across the
  /// *full* body — including the space the nav bar visually covers — and
  /// reads as sitting lower than true-center. Trip Suitcase (a pushed page,
  /// no floating nav bar) leaves this at 0.
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
              style: (title == null ? AppTextStyle.regular16 : AppTextStyle.regular14)
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
        // Clamped so a shorter-than-bottomInset viewport (very small
        // screens, or a test surface) can't go negative.
        final availableHeight = (constraints.maxHeight - bottomInset).clamp(
          0.0,
          double.infinity,
        );
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            // Tight, not just a minimum: SingleChildScrollView gives its
            // child unbounded (infinite) max height along the scroll axis,
            // so a minHeight-only constraint here would still leave
            // maxHeight at infinity — fine for most widgets, but the
            // StackFit.expand below explicitly sizes itself to fill
            // constraints.biggest, which is invalid when that's infinite.
            constraints: BoxConstraints(
              minHeight: availableHeight,
              maxHeight: availableHeight,
            ),
            child: Stack(
              // Pins the Stack's own size to the full incoming (body)
              // constraints regardless of its children — without this,
              // StackFit.loose lets it shrink to fit its non-positioned
              // children instead, which collapses toward 0x0 whenever
              // [pinnedTop] is absent or briefly empty (e.g. before a
              // provider resolves).
              fit: StackFit.expand,
              children: [
                // Non-positioned -> stretched to the full Stack by
                // StackFit.expand, so Center always has the whole body to
                // center in, whatever height [pinnedTop] currently has.
                Center(child: content),
                // Positioned (not full-bleed), so StackFit.expand doesn't
                // stretch this one too — it keeps its own natural height,
                // pinned to the top.
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
