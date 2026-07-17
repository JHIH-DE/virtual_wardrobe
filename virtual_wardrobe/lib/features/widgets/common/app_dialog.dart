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
        width: 292,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTextStyle.dialogTitle,
              ),
              const SizedBox(height: 8),
              widget.content ??
                  Text(
                    widget.body!,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.dialogBody,
                  ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.primaryLabel,
                  style: const TextStyle(color: AppColors.textOnPrimary),
                ),
              ),
              if (widget.secondaryLabel != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
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
