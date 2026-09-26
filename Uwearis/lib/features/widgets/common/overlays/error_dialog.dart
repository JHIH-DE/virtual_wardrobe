import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// The app's standard error prompt — an [AppDialog] with a single dismiss
/// button, replacing a `ScaffoldMessenger.showSnackBar` for a caught
/// exception's user-facing message. [message] should already be the result
/// of `apiErrorMessage(...)` or an equivalent safe, localized string — this
/// helper only supplies the dialog chrome, not the copy.
Future<void> showErrorDialog(
  BuildContext context, {
  required String message,
  String? title,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title ?? l10n.errorDialogTitle,
      body: message,
      primaryLabel: l10n.ok,
      onPrimary: () => Navigator.of(ctx).pop(),
    ),
  );
}
