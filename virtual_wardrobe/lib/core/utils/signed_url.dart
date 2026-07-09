/// Returns true if [url] is a GCS V4 signed URL (has `X-Goog-Date` /
/// `X-Goog-Expires` query params) whose expiry has passed, or is about to
/// pass within [buffer]. Non-signed URLs (missing those params) are treated
/// as never expiring.
bool isSignedUrlExpired(String url, {Duration buffer = const Duration(seconds: 30)}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;

  final dateParam = uri.queryParameters['X-Goog-Date'];
  final expiresParam = uri.queryParameters['X-Goog-Expires'];
  if (dateParam == null || expiresParam == null || dateParam.length < 15) {
    return false;
  }

  final expiresSeconds = int.tryParse(expiresParam);
  if (expiresSeconds == null) return false;

  try {
    final signedAt = DateTime.utc(
      int.parse(dateParam.substring(0, 4)),
      int.parse(dateParam.substring(4, 6)),
      int.parse(dateParam.substring(6, 8)),
      int.parse(dateParam.substring(9, 11)),
      int.parse(dateParam.substring(11, 13)),
      int.parse(dateParam.substring(13, 15)),
    );
    final expiresAt = signedAt.add(Duration(seconds: expiresSeconds));
    return DateTime.now().toUtc().isAfter(expiresAt.subtract(buffer));
  } catch (_) {
    return false;
  }
}
