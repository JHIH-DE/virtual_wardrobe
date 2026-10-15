import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';
import 'expand_arrow_icon.dart';

/// Tap-to-expand body for a [UwearisInsightCard]: a [title] row and a
/// detail paragraph that cross-fades in/out.
class ExpandableInsightBody extends StatelessWidget {
  final Widget title;
  final String detail;
  final bool expanded;
  final VoidCallback onToggle;

  /// False hides the arrow and disables the tap.
  final bool showToggle;

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
                style: AppTextStyle.insightCardBody.copyWith(
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
