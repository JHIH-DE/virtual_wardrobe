import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/api_exception.dart';
import '../services/auth_handler.dart';

/// ≈2.9s total, vs Riverpod's default of up to 10 retries (~38s).
const _retryDelays = [
  Duration(milliseconds: 300),
  Duration(milliseconds: 800),
  Duration(milliseconds: 1800),
];

/// `retry:` for every backend-talking provider declaration (not on
/// `ProviderScope`). Whitelist: only 5xx [ApiException], [TimeoutException],
/// [SocketException] and [http.ClientException] retry, at most 3 times.
/// [AuthExpiredException] never retries — the token refresh already failed.
Duration? appRetryPolicy(int retryCount, Object error) {
  if (error is AuthExpiredException) return null;

  final isTransient =
      (error is ApiException && error.statusCode >= 500) ||
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException;
  if (!isTransient) return null;

  if (retryCount >= _retryDelays.length) return null;
  return _retryDelays[retryCount];
}
