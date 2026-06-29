import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class BottomActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final Widget? trailing;
  final Color buttonColor;
  final Color textColor;
  final Color panelColor;
  final EdgeInsets panelPadding;
  final bool showShadow;

  const BottomActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.trailing,
    this.buttonColor = AppColors.defaultButton,
    this.textColor = AppColors.defaultButtonText,
    this.panelColor = AppColors.defaultToolBar,
    this.panelPadding = const EdgeInsets.fromLTRB(22, 22, 22, 8),
    this.showShadow = true,
  });

  bool get _isDisabled => !enabled || isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final iconColor = _isDisabled ? AppColors.textSecondary : textColor;

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: panelPadding,
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isDisabled ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                disabledBackgroundColor: AppColors.border,
                foregroundColor: textColor,
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
      ),
    );
  }
}
