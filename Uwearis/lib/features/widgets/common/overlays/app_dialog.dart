import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../buttons/action_button.dart';
import 'dialog_glass_panel.dart';

/// Where [AppDialog] puts the button that only closes it (pops `null`,
/// which every caller reads as cancel).
enum AppDialogDismiss {
  /// OK in the primary slot when there is no primary, else Cancel in the
  /// secondary slot when there is no secondary, else none.
  auto,

  /// A Cancel text button under every other button: for a dialog whose
  /// choices are option cards in [AppDialog.content], or whose primary and
  /// secondary are both real outcomes (Save / Don't Save).
  cancel,
}

/// The app's dialog. Buttons come in two kinds only: a filled primary (the
/// call to action — OK, Save, Delete) and a text secondary for a real
/// alternative outcome (Don't Save, Decline). The dismiss button follows
/// [dismiss].
class AppDialog extends StatelessWidget {
  static const dismissButtonKey = Key('app_dialog_dismiss');

  final String title;
  final String? body;
  final Widget? content;

  final String? primaryLabel;

  /// The same [ActionButton] `BottomActionButton` renders. Null shows it
  /// greyed out (still visible).
  final VoidCallback? onPrimary;

  /// Renders the primary as [ActionButtonVariant.destructive].
  final bool destructive;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final AppDialogDismiss dismiss;

  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    this.primaryLabel,
    this.onPrimary,
    this.destructive = false,
    this.secondaryLabel,
    this.onSecondary,
    this.dismiss = AppDialogDismiss.auto,
  }) : assert(
         body != null || content != null,
         'AppDialog requires either body or content',
       );

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    void close() => Navigator.of(context).pop();
    final auto = dismiss == AppDialogDismiss.auto;

    final buttons = <Widget>[
      if (primaryLabel != null)
        ActionButton(
          label: primaryLabel!,
          onPressed: onPrimary,
          variant: destructive
              ? ActionButtonVariant.destructive
              : ActionButtonVariant.primary,
        )
      else if (auto)
        ActionButton(
          key: dismissButtonKey,
          label: materialL10n.okButtonLabel,
          onPressed: close,
        ),
      if (secondaryLabel != null)
        _buildSecondaryButton(secondaryLabel!, onSecondary)
      else if (auto && primaryLabel != null)
        _buildSecondaryButton(
          materialL10n.cancelButtonLabel,
          close,
          key: dismissButtonKey,
        ),
      if (!auto)
        _buildSecondaryButton(
          materialL10n.cancelButtonLabel,
          close,
          key: dismissButtonKey,
        ),
    ];

    final radius = BorderRadius.circular(AppDimens.dialogRadius);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // DialogGlassPanel clips itself to the same radius.
      child: DialogGlassPanel(
        borderRadius: radius,
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.bold20,
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
                for (final (i, button) in buttons.indexed) ...[
                  SizedBox(height: i == 0 ? 16 : 12),
                  button,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    String label,
    VoidCallback? onPressed, {
    Key? key,
  }) {
    return TextButton(
      key: key,
      onPressed: onPressed,
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
