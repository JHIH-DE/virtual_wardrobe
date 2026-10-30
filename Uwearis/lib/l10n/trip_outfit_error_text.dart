import '../core/services/api_exception.dart';
import '../core/utils/api_error_text.dart';
import 'generated/app_localizations.dart';

/// [apiErrorMessage] plus the Trip Outfit Collection's own `error_code`s,
/// shared by Trip Details and the Suitcase page.
String tripOutfitErrorMessage(
  AppLocalizations l10n,
  Object error, {
  required String fallback,
}) {
  if (error is ApiException) {
    final mapped = switch (error.errorCode) {
      'TRIP_OUTFIT_ALREADY_ADDED' => l10n.tripOutfitAlreadyAdded,
      'TRIP_OUTFIT_DUPLICATE' => l10n.tripOutfitDuplicate,
      'TRIP_OUTFIT_INCOMPLETE' => l10n.tripOutfitIncomplete,
      'TRIP_OUTFIT_GARMENT_NOT_IN_SUITCASE' => l10n.tripOutfitGarmentNotPacked,
      'TRIP_OUTFIT_GARMENTS_MISSING' => l10n.tripOutfitMissingGarmentsTryOn,
      'TRIP_OUTFIT_LIMIT_REACHED' => l10n.tripOutfitLimitReached,
      'TRIP_OUTFIT_GENERATION_IN_PROGRESS' =>
        l10n.tripOutfitGenerationInProgress,
      'SAVED_OUTFIT_UNAVAILABLE' => l10n.savedOutfitUnavailable,
      _ => null,
    };
    if (mapped != null) return mapped;
  }
  return apiErrorMessage(l10n, error, fallback: fallback);
}
