import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

class AppDialog extends StatefulWidget {
  final String title;
  final String? body;
  final Widget? content;
  final String primaryLabel;

  /// Null shows the primary button greyed out (still visible).
  final VoidCallback? onPrimary;

  final IconData? primaryIcon;
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

  /// For a dialog whose only button is a dismiss: the filled accent style
  /// is reserved for real calls to action.
  final bool primaryIsTextButton;

  /// Border for the filled/outlined buttons; text-button variants stay
  /// chromeless.
  final BorderSide? borderSide;

  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
    this.width = 320,
    this.titleSpacing = 16,
    this.contentToPrimarySpacing = 16,
    this.secondaryIsTextButton = true,
    this.primaryIsTextButton = false,
    this.borderSide = const BorderSide(
      color: AppColors.borderOnDark,
      width: 1.5,
    ),
  }) : assert(
         body != null || content != null,
         'AppDialog requires either body or content',
       );

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
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
                style: AppTextStyle.bold20,
              ),
              SizedBox(height: widget.titleSpacing),
              widget.content ??
                  Text(
                    widget.body!,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.medium16,
                  ),
              SizedBox(height: widget.contentToPrimarySpacing),
              widget.primaryIsTextButton
                  ? TextButton(
                      onPressed: widget.onPrimary,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: Text(
                        widget.primaryLabel,
                        style: AppTextStyle.medium16.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : _buildPrimaryButton(),
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
                          style: AppTextStyle.medium14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: widget.onSecondary,
                        style: OutlinedButton.styleFrom(
                          side:
                              widget.borderSide ??
                              const BorderSide(
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
                          style: AppTextStyle.medium14.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
              ],
              if (widget.tertiaryLabel != null) ...[
                const SizedBox(height: 6),
                const Divider(thickness: 1, color: AppColors.borderSubtle),
                SizedBox(
                  width: 104,
                  child: TextButton(
                    onPressed: widget.onTertiary,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(0, 38),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                      side: widget.borderSide,
                    ),
                    child: Text(
                      widget.tertiaryLabel!,
                      style: AppTextStyle.medium14.copyWith(
                        color: AppColors.textPrimary,
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

  Widget _buildPrimaryButton() {
    final textColor = widget.onPrimary == null
        ? AppColors.hintText
        : AppColors.textOnPrimary;
    return ElevatedButton(
      onPressed: widget.onPrimary,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        disabledBackgroundColor: AppColors.borderSubtle,
        // Matches ActionButton's height.
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        side: widget.borderSide,
      ),
      child: widget.primaryIcon == null
          ? Text(
              widget.primaryLabel,
              style: AppTextStyle.medium16.copyWith(color: textColor),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.primaryIcon, size: 18, color: textColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.primaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.medium16.copyWith(color: textColor),
                  ),
                ),
              ],
            ),
    );
  }
}
