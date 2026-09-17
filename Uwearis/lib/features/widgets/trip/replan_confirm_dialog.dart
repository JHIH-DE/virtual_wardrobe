import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../common/overlays/app_dialog.dart';

/// The confirmation shown before an explicit Replan — shared by both entry
/// points (TripSuitcasePage's "Replan Trip Outfits" bottom button and
/// TripDetailsPage's Daily Outfit Plan refresh icon) so the policy is
/// explained in exactly the same words regardless of where it was triggered.
///
/// Returns `true` only if the user confirmed; `false` for Cancel or
/// dismissing the dialog (barrier tap / system back).
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
