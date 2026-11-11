import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../features/widgets/common/overlays/app_snack_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/points_provider.dart';

/// After a render that used an AI try-on (Create Outfit, Outfit Details'
/// regenerate, a trip outfit's try-on): re-reads the balance and shows it at
/// the bottom of whatever screen is up by then. Take [overlay]
/// (`Overlay.of(context, rootOverlay: true)`) and [points] before the
/// render's `await`. Says nothing when the balance can't be read.
Future<void> announceRemainingPoints(
  OverlayState overlay,
  AppLocalizations l10n,
  PointsNotifier points,
) async {
  final summary = await points.reloadPoints();
  if (summary == null || !overlay.mounted) return;
  final balance = NumberFormat.decimalPattern(
    l10n.localeName,
  ).format(summary.balance);
  showAppSnackBarOn(overlay, l10n.pointsRemaining(balance));
}
