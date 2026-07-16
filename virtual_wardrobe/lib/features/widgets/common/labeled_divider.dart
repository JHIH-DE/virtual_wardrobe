import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class LabeledDivider extends StatelessWidget {
  final String label;

  /// When set, shows a small colored dot before [label] (e.g. a status
  /// indicator like Ongoing/Upcoming/Past).
  final Color? dotColor;

  const LabeledDivider({super.key, required this.label, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(thickness: 1, color: AppColors.borderStrong),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
              Text(
                label,
                style: AppTextStyle.bold14.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Divider(thickness: 1, color: AppColors.borderStrong),
        ),
      ],
    );
  }
}
