import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'expand_arrow_icon.dart';

/// Tap-to-expand body for a [UwearisInsightCard]: a [title] row with an
/// [ExpandArrowIcon], and a detail paragraph that cross-fades in/out. Used
/// by Trip Details' packing advice and Trip garment selection's per-category
/// advice.
class ExpandableInsightBody extends StatelessWidget {
  /// The always-visible header — a `Text` or `SectionTitle`.
  final Widget title;
  final String detail;
  final bool expanded;
  final VoidCallback onToggle;

  /// When false the arrow is hidden and the tap does nothing (e.g. there's
  /// no reasoning to reveal).
  final bool showToggle;

  /// Optional line-height override for the detail paragraph (long advice
  /// text reads better at 1.5).
  final double? detailLineHeight;

  const ExpandableInsightBody({
    super.key,
    required this.title,
    required this.detail,
    required this.expanded,
    required this.onToggle,
    this.showToggle = true,
    this.detailLineHeight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: showToggle ? onToggle : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: title),
              if (showToggle) ExpandArrowIcon(expanded: expanded),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                detail,
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                  height: detailLineHeight,
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
