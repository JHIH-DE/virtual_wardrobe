import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../common/overlays/app_dialog.dart';

/// Confirmation before a Replan, shared by both entry points. `true` only
/// if confirmed.
Future<bool> showReplanConfirmDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: l10n.replanTripOutfitsTitle,
      body: l10n.replanTripOutfitsBody,
      primaryLabel: l10n.replan,
      onPrimary: () => Navigator.pop(ctx, true),
      secondaryLabel: l10n.cancel,
      onSecondary: () => Navigator.pop(ctx, false),
    ),
  );
  return confirmed ?? false;
}
