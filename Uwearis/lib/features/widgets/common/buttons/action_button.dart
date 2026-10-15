import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

enum ActionButtonVariant {
  /// Solid accent fill — the screen's main action.
  primary,

  /// Pale accent tint — an action that shouldn't compete with a primary one
  /// on the same screen.
  secondary,
}

/// Full-width pill call-to-action.
class ActionButton extends StatelessWidget {
  static final Color _secondaryDisabledForeground = AppColors.accent.withValues(
    alpha: 0.38,
  );

  final String label;
  final VoidCallback? onPressed;
  final ActionButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;

  const ActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ActionButtonVariant.primary,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (variant) {
      ActionButtonVariant.primary => (
        AppColors.accent,
        AppColors.textOnPrimary,
        const BorderSide(
          color: AppColors.borderOnDark,
          width: AppDimens.actionButtonBorderWidth,
        ),
      ),
      ActionButtonVariant.secondary => (
        AppColors.accentTint,
        onPressed == null ? _secondaryDisabledForeground : AppColors.accent,
        BorderSide.none,
      ),
    };
    var style = ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      side: border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.actionButtonRadius),
      ),
    );
    if (variant == ActionButtonVariant.secondary) {
      // The tint is the state feedback (no ripple); disabled is paler than
      // resting so it never reads as enabled.
      style = style.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.accent.withValues(alpha: 0.06);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.accent.withValues(alpha: 0.20);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return AppColors.accent.withValues(alpha: 0.16);
          }
          return AppColors.accentTint;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: AppDimens.actionButtonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(color: foreground),
                child: leading!,
              ),
              const SizedBox(width: AppDimens.actionButtonIconGap),
            ],
            Text(
              label,
              style: AppTextStyle.medium16.copyWith(color: foreground),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppDimens.actionButtonIconGap),
              IconTheme(
                data: IconThemeData(color: foreground),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
