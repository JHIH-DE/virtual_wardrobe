import '../../l10n/generated/app_localizations.dart';
import '../services/api_exception.dart';

/// Resolves a caught error to a message safe to show the user — the one
/// place every page's generic `catch (e)` should go through instead of
/// displaying [error] (or its `.toString()`) directly.
///
/// [fallback] is the caller's own ARB string for "this specific action
/// failed" (e.g. "Couldn't save your profile. Please try again.") and is
/// what's returned for anything this function doesn't recognize: a
/// non-[ApiException] error (timeout, a malformed-response check thrown
/// client-side, ...), an [ApiException] with no `errorCode`, or an
/// `errorCode` this app doesn't have a specific string for. Only a handful
/// of `error_code`s carry cross-cutting product meaning worth a shared,
/// specific string instead of the caller's own fallback — see
/// [_messageForErrorCode].
///
/// The backend's own `message` (on [ApiException]) is deliberately never
/// read here — it's meant for `debugLog`, not guaranteed to be
/// user-appropriate copy, and every call site already has a better,
/// action-specific fallback than a generic backend string.
String apiErrorMessage(
  AppLocalizations l10n,
  Object error, {
  required String fallback,
}) {
  if (error is ApiException) {
    final mapped = _messageForErrorCode(l10n, error.errorCode);
    if (mapped != null) return mapped;
  }
  return fallback;
}

/// Cross-cutting `error_code` → localized message mapping, shared by every
/// caller of [apiErrorMessage] instead of each page re-deriving its own
/// `switch`. Add a case here only once a code is confirmed against the
/// backend's `ErrorCode` enum and is common enough across features to be
/// worth a specific string instead of the calling screen's own generic
/// fallback — a code scoped to one feature (like closet-analysis's
/// `GARMENT_NOT_FOUND` or Match a Look's `MATCH_LOOK_NO_PERSON`) belongs in
/// that feature's own exception/switch, not here.
///
/// Confirmed backend codes not (yet) mapped here, on purpose:
/// - `OBJECT_NAME_REQUIRED` — not user-facing; a client request-shape bug,
///   not something the person did.
/// - `OUTFIT_COPY_FAILED` — still covered by `outfitCopyFailed`, the copy
///   flow's own fallback; no case added until a more specific message is
///   needed.
String? _messageForErrorCode(AppLocalizations l10n, String? errorCode) {
  switch (errorCode) {
    case 'FACE_REFERENCE_NOT_FOUND':
      return l10n.faceReferenceNotFound;
    case 'BODY_REFERENCE_NOT_FOUND':
      return l10n.bodyReferenceNotFound;
    case 'FILE_NOT_FOUND':
      return l10n.fileNotFound;
    default:
      return null;
  }
}
