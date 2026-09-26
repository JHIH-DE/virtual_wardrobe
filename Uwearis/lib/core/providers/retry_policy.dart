import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/api_exception.dart';
import '../services/auth_handler.dart';

/// Backoff before the 1st/2nd/3rd retry — short and capped at 3 attempts,
/// deliberately not Riverpod's own default (`ProviderContainer.defaultRetry`:
/// up to 10 retries, backoff doubling from 200ms up to a 6.4s cap — ~38s of
/// cumulative waiting before a caller ever sees a terminal state). Total
/// cumulative wait here is ≈2.9s.
const _retryDelays = [
  Duration(milliseconds: 300),
  Duration(milliseconds: 800),
  Duration(milliseconds: 1800),
];

/// This app's `retry:` policy for every backend-talking `AsyncNotifierProvider`
/// / `FutureProvider` — pass it as the `retry:` argument on the provider
/// declaration (not on `ProviderScope`, which would silently change the
/// behaviour of any other provider nobody has reviewed for it yet).
///
/// Only applies to a provider's `build()` — every provider's own `refresh()`
/// already self-guards with `AsyncValue.guard`, which catches the error
/// directly into `AsyncError` and never reaches Riverpod's retry machinery
/// at all.
///
/// **Whitelist, not blacklist**: the default is "don't retry" — only the
/// specific transient-looking error shapes below get a retry, capped at 3
/// attempts. Everything else fails on the first try, so a page's `catch`,
/// an `await provider.future`, or an `AuthExpiredException` listener sees it
/// immediately instead of sitting through a silent loading spin:
///
/// - [AuthExpiredException] — never retried. It already means the token
///   refresh inside `BaseService.withAuth` was attempted and failed
///   unrecoverably; retrying the original request can't change that, and
///   doing so only delays `AuthExpiredHandler`/the session-expired flow.
/// - [ApiException] with `statusCode >= 500` — retried (a transient
///   server-side hiccup is plausible). Any other [ApiException] (4xx) is
///   not — the request itself won't succeed no matter how many times it's
///   repeated.
/// - [TimeoutException], [SocketException], [http.ClientException] —
///   retried (transport-level: a flaky connection, a slow/cold backend).
/// - Anything else — `ClosetAnalysisException`, `MatchLookException`, a
///   location permission/service `Exception` (see `weatherProvider`), a
///   plain unclassified `Exception`, a `FormatException`, an `Error` (a
///   programming bug) — never retried. These already have their own UI
///   handling (a specific `catch`/switch) or would never succeed on retry
///   regardless of how many times it's attempted.
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
