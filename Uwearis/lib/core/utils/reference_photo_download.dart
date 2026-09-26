import 'dart:io';

import 'package:http/http.dart' as http;

import 'debug_log.dart';

/// Downloads [url] to a local temp file so a caller can hand
/// `ImageEditorPage` a definitely-valid local original instead of a
/// possibly-already-expired signed URL — see `my_virtual_model_page.dart`'s
/// `_MyVirtualModelPageState._changePhoto`, the motivating caller.
///
/// If the initial download fails (e.g. an expired GCS signed URL), calls
/// [onRefreshUrl] once for a fresh URL, reports it via [onUrlRefreshed] (so
/// the caller's own longer-lived copy — e.g. `profileProvider` — stays in
/// sync with whatever the backend just handed back, the same URL this
/// function is about to use), and retries the download once with it.
///
/// Returns null if the file still can't be fetched — a genuinely missing/
/// broken reference, not just a stale signed URL. The caller must not open
/// the editor with a null path when [url] was non-null to begin with.
///
/// Whatever [onRefreshUrl] itself throws (e.g. `AuthExpiredException`)
/// propagates unchanged, so the caller's own auth-handling stays in one
/// place instead of this function swallowing it.
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
