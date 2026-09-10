import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// How a [NumberStepper] frames itself.
/// - [card]: the standalone bordered white field (default).
/// - [row]: a bare list row, for a stepper sitting alongside other rows
///   inside a shared card.
///
/// Both keep only slim outer padding — the minus/plus buttons carry their
/// own [AppDimens.minTouchTarget]-tall transparent hit area, which sets the
/// control's height.
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
          trailing: true,
        ),
      ],
    );

    if (variant == NumberStepperVariant.row) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: row,
    );
  }

  static const double _glyphSize = 18;
  // Transparent pad on each side of the glyph that grows it to a
  // minTouchTarget hit area.
  static const double _hitPad = (AppDimens.minTouchTarget - _glyphSize) / 2;

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool trailing = false,
  }) {
    return GestureDetector(
      // opaque so the transparent pad around the 18px glyph is tappable too.
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        // The trailing (+) button drops its right-side hit pad so the glyph
        // sits flush with the row's right edge, matching a trailing chevron;
        // the hit area stays full-height, just [_hitPad] narrower.
        width: trailing ? _glyphSize + _hitPad : AppDimens.minTouchTarget,
        height: AppDimens.minTouchTarget,
        child: Align(
          alignment: trailing ? Alignment.centerRight : Alignment.center,
          child: Icon(
            icon,
            size: _glyphSize,
            color: onPressed == null
                ? AppColors.icon.withValues(alpha: 0.3)
                : AppColors.icon,
          ),
        ),
      ),
    );
  }
}
