import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// How a [NumberStepper] frames itself.
/// - [card]: the standalone bordered white field (default).
/// - [row]: a bare list row (`vertical: 14` padding only), for a stepper
///   sitting alongside other rows inside a shared card.
enum NumberStepperVariant { card, row }

/// A label + minus/value/plus stepper control — bordered card by default,
/// or a bare list row via [NumberStepperVariant.row].
class NumberStepper extends StatelessWidget {
  final String label;
  final String valueLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final NumberStepperVariant variant;

  const NumberStepper({
    super.key,
    required this.label,
    required this.valueLabel,
    this.onDecrement,
    this.onIncrement,
    this.variant = NumberStepperVariant.card,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
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
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Text(
            valueLabel,
            textAlign: TextAlign.center,
            style: AppTextStyle.bold16,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        const SizedBox(width: 6),
        _buildStepButton(
          icon: Icons.add_circle_outline,
          onPressed: onIncrement,
        ),
      ],
    );

    if (variant == NumberStepperVariant.row) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: row,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: row,
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
