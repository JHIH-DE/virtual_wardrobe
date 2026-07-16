import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Bordered row with a label and a minus/value/plus stepper control.
class NumberStepper extends StatelessWidget {
  final String label;
  final String valueLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const NumberStepper({
    super.key,
    required this.label,
    required this.valueLabel,
    this.onDecrement,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyle.regular14)),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(
              Icons.remove_circle_outline,
              color: AppColors.icon,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              valueLabel,
              textAlign: TextAlign.center,
              style: AppTextStyle.bold18,
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.icon),
          ),
        ],
      ),
    );
  }
}
