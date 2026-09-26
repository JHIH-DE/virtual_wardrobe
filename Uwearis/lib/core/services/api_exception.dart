import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown by [BaseService.decodeMap] — and any other service that decodes
/// the backend's `BaseResponse[T]` envelope the same way — for a non-2xx
/// response that isn't an expired session (see `AuthExpiredException` in
/// `auth_handler.dart` for that case, which is checked before this is ever
/// thrown).
///
/// Carries only what's safe to build on: [statusCode] always, and
/// [errorCode] when the response body parses as the backend's envelope and
/// carries one. [message] is the backend's own `message` field (or a
/// generic fallback when the body doesn't have one) — it exists for
/// `debugLog`/diagnostics, not to be shown to the user by default. A
/// backend string isn't guaranteed to be end-user-appropriate copy, and
/// every UI call site already has its own action-specific ARB fallback; see
/// `lib/core/utils/api_error_text.dart`'s `apiErrorMessage`, which maps
/// [errorCode] to a localized string when one of the handful of shared,
/// product-meaningful codes matches and otherwise returns the caller's
/// fallback untouched.
class ApiException implements Exception {
  final int statusCode;
  final String? errorCode;
  final String message;

  const ApiException({
    required this.statusCode,
    this.errorCode,
    required this.message,
  });

  /// Builds an [ApiException] from a non-2xx [http.Response]. Parses the
  /// backend's envelope (`error_code`/`message`) when the body is a JSON
  /// object shaped that way; falls back to a status-only exception for
  /// anything else (not JSON, not an object, missing fields) — this never
  /// throws itself, so a malformed error body can't turn into a second,
  /// more confusing failure at the call site.
  factory ApiException.fromResponse(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return ApiException(
          statusCode: res.statusCode,
          errorCode: decoded['error_code'] as String?,
          message: (decoded['message'] as String?) ?? 'Request failed',
        );
      }
    } catch (_) {
      // Body isn't valid JSON — fall through to the status-only exception.
    }
    return ApiException(statusCode: res.statusCode, message: 'Request failed');
  }

  // Deliberately omits [message] (the backend's own string) — this is the
  // fallback text if something ever does print an ApiException directly
  // (it shouldn't; see the class doc), and it should never carry more than
  // the status/code even then. The raw response body used to build this
  // exception belongs in `debugLog` only — see `BaseService.decodeMap`.
  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, errorCode: $errorCode)';
}
