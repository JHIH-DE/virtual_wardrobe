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

  static const double _labelVerticalPadding = 12;
  static const double _labelHorizontalPadding = 24;
  static const double _iconSize = 24;

  /// The width a button needs to show [label] on one line under [context]'s
  /// text scale. A parent placing two buttons side by side stacks them
  /// instead when either one needs more than its share.
  static double oneLineWidthFor(
    BuildContext context,
    String label, {
    bool hasIcon = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: AppTextStyle.medium16),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width =
        painter.width +
        2 * _labelHorizontalPadding +
        (hasIcon ? _iconSize + AppDimens.actionButtonIconGap : 0);
    painter.dispose();
    return width;
  }

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
    final disabled = onPressed == null;
    final (background, foreground, border) = switch (variant) {
      // Disabled matches AppDialog's disabled primary.
      ActionButtonVariant.primary when disabled => (
        AppColors.borderSubtle,
        AppColors.hintText,
        BorderSide.none,
      ),
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
        disabled ? _secondaryDisabledForeground : AppColors.accent,
        BorderSide.none,
      ),
    };
    var style = ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: background,
      disabledForegroundColor: foreground,
      elevation: 0,
      minimumSize: const Size.fromHeight(AppDimens.actionButtonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: _labelHorizontalPadding,
        vertical: _labelVerticalPadding,
      ),
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
    // Grows taller rather than truncating: a long or enlarged label wraps.
    return SizedBox(
      width: double.infinity,
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
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyle.medium16.copyWith(color: foreground),
              ),
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
