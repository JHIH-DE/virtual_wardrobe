import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../buttons/action_button.dart';
import '../buttons/circle_icon_button.dart';

/// The app's dialog. The top-right X closes it (popping `null`, which every
/// caller reads as cancel), so there is no Cancel/Close button. Buttons come
/// in two kinds only: a filled accent primary (the call to action — OK,
/// Save) and a text secondary for a real alternative outcome (Don't Save,
/// Decline).
class AppDialog extends StatelessWidget {
  static const closeButtonKey = Key('app_dialog_close');

  final String title;
  final String? body;
  final Widget? content;

  final String? primaryLabel;

  /// The same [ActionButton] `BottomActionButton` renders. Null shows it
  /// greyed out (still visible).
  final VoidCallback? onPrimary;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  }) : assert(
         body != null || content != null,
         'AppDialog requires either body or content',
       );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 320,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clears the close button on both sides, so the title stays
                  // centered.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyle.bold20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Scrolls when long (enlarged text, a full disclosure) so the
                  // buttons below always stay on screen.
                  Flexible(
                    child: SingleChildScrollView(
                      child:
                          content ??
                          Text(
                            body!,
                            textAlign: TextAlign.center,
                            style: AppTextStyle.medium16,
                          ),
                    ),
                  ),
                  if (primaryLabel != null || secondaryLabel != null)
                    const SizedBox(height: 16),
                  if (primaryLabel != null)
                    ActionButton(label: primaryLabel!, onPressed: onPrimary),
                  if (secondaryLabel != null) ...[
                    if (primaryLabel != null) const SizedBox(height: 12),
                    _buildSecondaryButton(secondaryLabel!),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: CircleIconButton(
                key: closeButtonKey,
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                discAlignment: Alignment.topRight,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label) {
    return TextButton(
      onPressed: onSecondary,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        minimumSize: const Size(double.infinity, 40),
      ),
      child: Text(
        label,
        style: AppTextStyle.medium14.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
