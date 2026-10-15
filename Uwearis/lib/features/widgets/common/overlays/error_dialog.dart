import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// The standard error prompt. [message] must already be safe, localized
/// copy (e.g. from `apiErrorMessage`). With [onRetry] the dialog offers
/// Retry / Cancel and runs [onRetry] after closing on Retry.
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
