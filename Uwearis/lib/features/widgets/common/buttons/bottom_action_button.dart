import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

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

  // Was an overridable param (default 56); the one call site that needed a
  // shorter bar (Outfit Details' "Edit Outfit" button) is the only value
  // actually in use, so that's now the fixed height everywhere.
  static const double _height = 48;

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
    this.panelPadding = const EdgeInsets.fromLTRB(22, 0, 22, 0),
    this.borderSide = const BorderSide(
      color: AppColors.borderOnDark,
      width: 1.5,
    ),
  });

  // Hidden whenever the action can't currently be taken — genuinely
  // disabled, or a request for it is already in flight — rather than
  // showing a grayed-out or spinner state in place.
  bool get _isUnavailable => !enabled || onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isUnavailable
          ? const SizedBox.shrink(key: ValueKey('bottomActionButton-hidden'))
          : _buildButton(key: const ValueKey('bottomActionButton-visible')),
    );
  }

  // Only ever built while the action is actually available (see
  // _isUnavailable), so onPressed is always non-null here — no disabled
  // styling to account for.
  Widget _buildButton({required Key key}) {
    return Padding(
      key: key,
      padding: panelPadding,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: SizedBox(
          width: double.infinity,
          height: _height,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: textColor,
              elevation: 0,
              side: borderSide,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: textColor),
                    child: leading!,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppTextStyle.medium16.copyWith(color: textColor),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  IconTheme(
                    data: IconThemeData(color: textColor),
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
