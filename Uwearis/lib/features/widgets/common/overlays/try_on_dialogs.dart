import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// Before leaving a screen mid-render (its Stop Waiting action or a system
/// back): the render isn't cancelled, and counts if it finishes. True to
/// leave.
Future<bool> showStopWaitingDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final stop = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: l10n.stopWaitingTitle,
      body: l10n.stopWaitingBody,
      primaryLabel: l10n.stopWaiting,
      onPrimary: () => Navigator.pop(ctx, true),
      secondaryLabel: l10n.keepWaiting,
      onSecondary: () => Navigator.pop(ctx, false),
    ),
  );
  return stop == true;
}

/// Before sending another render while the previous one's outcome can't be
/// checked — it may still finish, so this one may use another try-on. True
/// to send.
Future<bool> showRetryWhileUnknownDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final retry = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: l10n.tryOnRetryUnknownTitle,
      body: l10n.tryOnRetryUnknownBody,
      primaryLabel: l10n.retry,
      onPrimary: () => Navigator.pop(ctx, true),
    ),
  );
  return retry == true;
}
