import 'dart:io';

import 'package:http/http.dart' as http;

import 'debug_log.dart';

/// Downloads [url] to a temp file so `ImageEditorPage` gets a local original
/// rather than a possibly-expired signed URL. On failure, retries once with
/// a URL from [onRefreshUrl] (reported via [onUrlRefreshed]).
///
/// Returns null if the file still can't be fetched. Errors thrown by
/// [onRefreshUrl] (e.g. `AuthExpiredException`) propagate to the caller.
Future<String?> downloadReferencePhotoOriginal({
  required String url,
  required String fileNamePrefix,
  required Future<String?> Function() onRefreshUrl,
  required void Function(String freshUrl) onUrlRefreshed,
}) async {
  Future<String?> tryDownload(String downloadUrl) async {
    try {
      final res = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final path =
          '${Directory.systemTemp.path}/'
          '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(res.bodyBytes);
      return path;
    } catch (e) {
      debugLog('downloadReferencePhotoOriginal: download failed: $e');
      return null;
    }
  }

  final direct = await tryDownload(url);
  if (direct != null) return direct;

  final fresh = await onRefreshUrl();
  if (fresh == null || fresh.isEmpty || fresh == url) return null;
  onUrlRefreshed(fresh);
  return tryDownload(fresh);
}
