import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyle.semibold16,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildStepButton(
            icon: Icons.remove_circle_outline,
            onPressed: onDecrement,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text(
              valueLabel,
              textAlign: TextAlign.center,
              style: AppTextStyle.bold16,
            ),
          ),
          const SizedBox(width: 6),
          _buildStepButton(
            icon: Icons.add_circle_outline,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 20,
        height: 20,
        child: Icon(
          icon,
          size: 18,
          color: onPressed == null
              ? AppColors.icon.withValues(alpha: 0.3)
              : AppColors.icon,
        ),
      ),
    );
  }
}
