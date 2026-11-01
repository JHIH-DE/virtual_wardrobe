import '../data/trip_outfit.dart';
import 'generated/app_localizations.dart';

/// The one-line outcome of Plan / Add AI Outfits / Refresh, shared by Trip
/// Details and the Suitcase page. Saved outfits added before an AI failure or
/// rate limit stay, so that reads as a partial success, not an error.
String tripOutfitGenerateMessage(
  AppLocalizations l10n,
  TripOutfitGenerateResult result, {
  required TripOutfitGenerateMode mode,
}) {
  final saved = result.savedAddedCount;
  final ai = result.aiAddedCount;
  if (mode == TripOutfitGenerateMode.refresh) {
    return result.replacedCount > 0
        ? l10n.refreshedAiOutfitsCount(result.replacedCount)
        : l10n.noMoreTripOutfitCombinations;
  }
  final aiIncomplete =
      result.aiStatus == TripOutfitAiStatus.failed ||
      result.aiStatus == TripOutfitAiStatus.rateLimited;
  if (saved > 0 && aiIncomplete) return l10n.tripAiPartialFailure;
  if (saved > 0 && ai > 0) return l10n.addedSavedAndAiOutfits(saved, ai);
  if (saved > 0) return l10n.addedSavedOutfitsOnly(saved);
  if (ai > 0) return l10n.addedAiOutfitsOnly(ai);
  return l10n.noMoreTripOutfitCombinations;
}
