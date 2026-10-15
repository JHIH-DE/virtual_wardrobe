import '../../l10n/generated/app_localizations.dart';
import '../services/api_exception.dart';

/// A user-safe message for a caught error: a shared string for a known
/// cross-cutting `error_code`, otherwise the caller's action-specific
/// [fallback]. The backend `message` is deliberately never shown.
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

/// Only cross-cutting codes confirmed against the backend's `ErrorCode`;
/// feature-scoped codes belong in that feature's own exception path.
/// `OBJECT_NAME_REQUIRED` is unmapped on purpose — a client bug, not user-facing.
String? _messageForErrorCode(AppLocalizations l10n, String? errorCode) {
  switch (errorCode) {
    case 'FACE_REFERENCE_NOT_FOUND':
      return l10n.facePhotoNotFound;
    case 'BODY_REFERENCE_NOT_FOUND':
      return l10n.fullBodyPhotoNotFound;
    case 'FILE_NOT_FOUND':
      return l10n.fileNotFound;
    default:
      return null;
  }
}
