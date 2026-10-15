import 'dart:convert';

import 'package:http/http.dart' as http;

http.Response jsonResponse(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// The backend's `BaseResponse[T]` envelope.
Map<String, dynamic> envelope(Object? data) => {
  'success': true,
  'message': 'ok',
  'data': data,
  'error_code': null,
};

/// A GCS V4 signed URL that expired in 2020.
const expiredSignedUrl =
    'https://storage.googleapis.com/x.jpg'
    '?X-Goog-Date=20200101T000000Z&X-Goog-Expires=60';
