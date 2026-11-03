import 'dart:convert';

import 'package:http/http.dart' as http;

/// A non-2xx backend response (other than an expired session). [message] is
/// the backend's own string, for diagnostics only — UI copy goes through
/// `apiErrorMessage`.
class ApiException implements Exception {
  final int statusCode;
  final String? errorCode;
  final String message;

  /// The backend's `x-request-id` (its api_logs `request_guid`); only
  /// signed-in /api/v1 responses carry it.
  final String? requestId;

  const ApiException({
    required this.statusCode,
    this.errorCode,
    required this.message,
    this.requestId,
  });

  /// Never throws: a malformed body falls back to a status-only exception.
  factory ApiException.fromResponse(http.Response res) {
    final requestId = res.headers['x-request-id'];
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return ApiException(
          statusCode: res.statusCode,
          errorCode: decoded['error_code'] as String?,
          message: (decoded['message'] as String?) ?? 'Request failed',
          requestId: requestId,
        );
      }
    } catch (_) {}
    return ApiException(
      statusCode: res.statusCode,
      message: 'Request failed',
      requestId: requestId,
    );
  }

  // Deliberately omits the backend [message].
  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, errorCode: $errorCode, '
      'requestId: $requestId)';
}
