import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// The standard error prompt. [message] must already be safe, localized
/// copy (e.g. from `apiErrorMessage`). With [onRetry] the dialog offers
/// Retry and runs [onRetry] after closing on Retry; the X closes it.
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
        ? AppDialog(title: title ?? l10n.errorDialogTitle, body: message)
        : AppDialog(
            title: title ?? l10n.errorDialogTitle,
            body: message,
            primaryLabel: l10n.retry,
            onPrimary: () => Navigator.of(ctx).pop(true),
          ),
  );
  if (retry == true) onRetry?.call();
}
