import 'dart:convert';

import 'package:http/http.dart' as http;

/// A JSON `http.Response` with the given [body] encoded and a JSON
/// content-type header.
http.Response jsonResponse(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// The backend's `BaseResponse[T]` envelope shape every service call receives.
Map<String, dynamic> envelope(Object? data) => {
  'success': true,
  'message': 'ok',
  'data': data,
  'error_code': null,
};

/// A GCS V4 signed URL whose window lapsed in 2020 — `isSignedUrlExpired`
/// treats it as stale.
const expiredSignedUrl =
    'https://storage.googleapis.com/x.jpg'
    '?X-Goog-Date=20200101T000000Z&X-Goog-Expires=60';
