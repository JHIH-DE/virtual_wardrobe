import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

enum SaveChangesChoice { save, discard, cancel }

/// The shared unsaved-changes prompt. There is no Cancel button: dismissing
/// it (barrier tap / back) counts as [SaveChangesChoice.cancel].
Future<SaveChangesChoice> showSaveChangesDialog(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showDialog<SaveChangesChoice>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      body: body,
      primaryLabel: l10n.save,
      onPrimary: () => Navigator.pop(ctx, SaveChangesChoice.save),
      secondaryLabel: l10n.dontSave,
      onSecondary: () => Navigator.pop(ctx, SaveChangesChoice.discard),
    ),
  );
  return choice ?? SaveChangesChoice.cancel;
}
