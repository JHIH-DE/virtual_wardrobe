import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class BottomActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final Widget? leading;
  final Widget? trailing;
  final Color buttonColor;
  final Color textColor;
  final EdgeInsets panelPadding;
  final BorderSide? borderSide;
  final double height;

  const BottomActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.leading,
    this.trailing,
    this.buttonColor = AppColors.accent,
    this.textColor = AppColors.textOnPrimary,
    this.panelPadding = const EdgeInsets.fromLTRB(22, 22, 22, 0),
    this.borderSide,
    this.height = 56,
  });

  bool get _isDisabled => !enabled || isLoading || onPressed == null;

  // Genuinely disabled (not just mid-request) — hide the whole button
  // instead of showing a grayed-out state.
  bool get _isUnavailable => !isLoading && (!enabled || onPressed == null);

  @override
  Widget build(BuildContext context) {
    if (_isUnavailable) return const SizedBox.shrink();

    final iconColor = _isDisabled ? AppColors.textSecondary : textColor;

    return Padding(
      padding: panelPadding,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: ElevatedButton(
            onPressed: _isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              disabledBackgroundColor: AppColors.borderSubtle,
              foregroundColor: textColor,
              disabledForegroundColor: AppColors.textSecondary,
              elevation: 0,
              side: borderSide,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: textColor,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[
                        IconTheme(
                          data: IconThemeData(color: iconColor),
                          child: leading!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        IconTheme(
                          data: IconThemeData(color: iconColor),
                          child: trailing!,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
