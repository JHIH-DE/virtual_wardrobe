import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../l10n/generated/app_localizations.dart';
import '../services/api_exception.dart';

/// A user-safe message for a caught error: a shared string for a known
/// cross-cutting `error_code`, a rate limit, or being offline — the cases
/// where retrying right away can't help — otherwise the caller's
/// action-specific [fallback] (5xx and timeouts included: it already says
/// what failed and to try again). The backend `message` is never shown.
String apiErrorMessage(
  AppLocalizations l10n,
  Object error, {
  required String fallback,
}) {
  if (error is ApiException) {
    final mapped = _messageForErrorCode(l10n, error.errorCode);
    if (mapped != null) return mapped;
    if (error.statusCode == 429) return l10n.errorTooManyRequests;
    return fallback;
  }
  if (error is SocketException || error is http.ClientException) {
    return l10n.errorNoConnection;
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
    case 'DAILY_GENERATION_LIMIT_EXCEEDED':
      final reset = nextGenerationQuotaReset(DateTime.now());
      final hh = reset.hour.toString().padLeft(2, '0');
      final mm = reset.minute.toString().padLeft(2, '0');
      return l10n.dailyGenerationLimitReached('$hh:$mm');
    default:
      return null;
  }
}

/// When the daily try-on quota resets, in the device's time zone. Mirrors
/// the backend (`resets_at`): 00:00 Asia/Taipei, a fixed UTC+8 with no DST.
@visibleForTesting
DateTime nextGenerationQuotaReset(DateTime now) {
  const taipeiOffset = Duration(hours: 8);
  final taipei = now.toUtc().add(taipeiOffset);
  final nextMidnight = DateTime.utc(taipei.year, taipei.month, taipei.day + 1);
  return nextMidnight.subtract(taipeiOffset).toLocal();
}
