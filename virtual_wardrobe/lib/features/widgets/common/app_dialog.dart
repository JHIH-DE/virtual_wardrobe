import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class AppDialog extends StatefulWidget {
  final String title;
  final String? body;
  final Widget? content;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
  final double width;
  final double titleSpacing;
  final double contentToPrimarySpacing;

  /// When true, [secondaryLabel] renders as a low-emphasis centered text
  /// button instead of a full-width outlined button.
  final bool secondaryIsTextButton;

  /// When true, the primary button renders as the same low-emphasis
  /// centered text button used for [secondaryLabel]. Use for dialogs whose
  /// sole button is a dismiss action (e.g. a list picker's "Cancel") rather
  /// than a true call to action — accent orange and filled buttons are
  /// reserved for actual primary actions.
  final bool primaryIsTextButton;

  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
    this.width = 292,
    this.titleSpacing = 16,
    this.contentToPrimarySpacing = 20,
    this.secondaryIsTextButton = true,
    this.primaryIsTextButton = false,
  }) : assert(
         body != null || content != null,
         'AppDialog requires either body or content',
       );

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  bool _tertiaryPressed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTextStyle.dialogTitle,
              ),
              SizedBox(height: widget.titleSpacing),
              widget.content ??
                  Text(
                    widget.body!,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.dialogBody,
                  ),
              SizedBox(height: widget.contentToPrimarySpacing),
              if (widget.primaryIsTextButton) ...[
                const Divider(thickness: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 4),
              ],
              widget.primaryIsTextButton
                  ? TextButton(
                      onPressed: widget.onPrimary,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: Text(
                        widget.primaryLabel,
                        style: AppTextStyle.regular16.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: widget.onPrimary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.primaryLabel,
                        style: AppTextStyle.regular16.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
              if (widget.secondaryLabel != null) ...[
                SizedBox(height: widget.secondaryIsTextButton ? 12 : 16),
                widget.secondaryIsTextButton
                    ? TextButton(
                        onPressed: widget.onSecondary,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                        child: Text(
                          widget.secondaryLabel!,
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: widget.onSecondary,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.textPrimary,
                            width: 1.6,
                          ),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.secondaryLabel!,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
              ],
              if (widget.tertiaryLabel != null) ...[
                const SizedBox(height: 6),
                const Divider(thickness: 1, color: AppColors.borderSubtle),
                SizedBox(
                  width: 104,
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _tertiaryPressed = true),
                    onTapUp: (_) {
                      setState(() => _tertiaryPressed = false);
                      widget.onTertiary?.call();
                    },
                    onTapCancel: () => setState(() => _tertiaryPressed = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: 38,
                      decoration: BoxDecoration(
                        color: _tertiaryPressed
                            ? AppColors.accent
                            : AppColors.surface,
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: 1.6,
                        ),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.tertiaryLabel!,
                        style: AppTextStyle.regular14.copyWith(
                          color: _tertiaryPressed
                              ? AppColors.textOnPrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
