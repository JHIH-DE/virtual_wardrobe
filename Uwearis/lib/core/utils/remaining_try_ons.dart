import 'package:flutter/widgets.dart';

import '../../features/widgets/common/overlays/app_snack_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../services/outfit_service.dart';
import 'debug_log.dart';

/// After a render that used an AI try-on (Create Outfit, Outfit Details'
/// regenerate, a trip outfit's try-on): re-reads the count and shows what's
/// left at the bottom of whatever screen is up by then. Take [overlay]
/// (`Overlay.of(context, rootOverlay: true)`) before the render's `await`.
/// Says nothing for an unlimited tier or when the count can't be read.
Future<void> announceRemainingTryOns(
  OverlayState overlay,
  AppLocalizations l10n,
) async {
  try {
    final quota = await OutfitService().getGenerationQuota();
    final remaining = quota.remaining;
    if (quota.isUnlimited || remaining == null) return;
    showAppSnackBarOn(overlay, l10n.generationQuotaRemaining(remaining));
  } catch (e) {
    debugLog('announceRemainingTryOns: count unavailable: $e');
  }
}
