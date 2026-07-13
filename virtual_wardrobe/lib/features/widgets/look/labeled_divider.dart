import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class LabeledDivider extends StatelessWidget {
  final String label;

  const LabeledDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(thickness: 1, color: AppColors.defaultDivider),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTextStyle.bold16.copyWith(
              color: AppColors.defaultDivider,
            ),
          ),
        ),
        const Expanded(
          child: Divider(thickness: 1, color: AppColors.defaultDivider),
        ),
      ],
    );
  }
}
