import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uwearis/core/services/api_exception.dart';

void main() {
  group('ApiException.fromResponse requestId', () {
    test('reads x-request-id from an enveloped error', () {
      final e = ApiException.fromResponse(
        http.Response(
          '{"error_code": "INTERNAL_SERVER_ERROR", "message": "boom"}',
          500,
          headers: {'x-request-id': 'req-123'},
        ),
      );
      expect(e.requestId, 'req-123');
      expect(e.errorCode, 'INTERNAL_SERVER_ERROR');
      expect(e.toString(), contains('requestId: req-123'));
      expect(e.toString(), isNot(contains('boom')));
    });

    test('keeps it when the body is not JSON', () {
      final e = ApiException.fromResponse(
        http.Response('<html>', 502, headers: {'x-request-id': 'req-9'}),
      );
      expect(e.statusCode, 502);
      expect(e.requestId, 'req-9');
    });

    test('is null when the backend sent none', () {
      final e = ApiException.fromResponse(http.Response('{}', 500));
      expect(e.requestId, isNull);
    });
  });
}
