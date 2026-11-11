import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'section_title.dart';

/// [label] centred between two rules; a label too long for one line wraps,
/// keeping at least [minRuleWidth] of rule on each side.
class LabeledDivider extends StatelessWidget {
  static const double minRuleWidth = 24;
  static const double _labelPadding = 12;

  final String label;

  /// Optional status dot before [label].
  final Color? dotColor;

  const LabeledDivider({super.key, required this.label, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          const Expanded(
            child: Divider(thickness: 1, color: AppColors.borderStrong),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth - minRuleWidth * 2,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _labelPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: SectionTitle(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyle.semibold16.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: Divider(thickness: 1, color: AppColors.borderStrong),
          ),
        ],
      ),
    );
  }
}
