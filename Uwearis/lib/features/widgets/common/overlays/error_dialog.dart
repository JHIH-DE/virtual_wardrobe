import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// The app's standard error prompt — an [AppDialog] with a single dismiss
/// button, replacing a `ScaffoldMessenger.showSnackBar` for a caught
/// exception's user-facing message. [message] should already be the result
/// of `apiErrorMessage(...)` or an equivalent safe, localized string — this
/// helper only supplies the dialog chrome, not the copy.
///
/// Pass [onRetry] when the failed action can simply be run again (e.g. an
/// auto-save): the dialog then offers Retry / Cancel, and [onRetry] runs
/// after it closes on Retry.
Future<void> showErrorDialog(
  BuildContext context, {
  required String message,
  String? title,
  VoidCallback? onRetry,
}) async {
  final l10n = AppLocalizations.of(context);
  final retry = await showDialog<bool>(
    context: context,
    builder: (ctx) => onRetry == null
        ? AppDialog(
            title: title ?? l10n.errorDialogTitle,
            body: message,
            primaryLabel: l10n.ok,
            onPrimary: () => Navigator.of(ctx).pop(),
          )
        : AppDialog(
            title: title ?? l10n.errorDialogTitle,
            body: message,
            primaryLabel: l10n.retry,
            onPrimary: () => Navigator.of(ctx).pop(true),
            secondaryLabel: l10n.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
          ),
  );
  if (retry == true) onRetry?.call();
}
