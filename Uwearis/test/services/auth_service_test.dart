import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_service.dart';

const _base = 'http://10.0.2.2:8000/api/v1/auth';

http.Response _jsonResponse(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _envelope(Object? data) => {
  'success': true,
  'message': 'ok',
  'data': data,
  'error_code': null,
};

void main() {
  group('loginWithGoogleIdToken', () {
    test('POSTs the id_token and returns both tokens', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'access_token': 'access-1', 'refresh_token': 'refresh-1'}),
        );
      });

      final result = await http.runWithClient(
        () => AuthService().loginWithGoogleIdToken('id-token-abc'),
        () => client,
      );

      expect(result.accessToken, 'access-1');
      expect(result.refreshToken, 'refresh-1');
      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_base/google');
      expect(jsonDecode(captured.body), {'id_token': 'id-token-abc'});
    });

    test('throws when access_token is missing', () async {
      final client = MockClient(
        (request) async =>
            _jsonResponse(_envelope({'refresh_token': 'refresh-1'})),
      );

      await expectLater(
        http.runWithClient(
          () => AuthService().loginWithGoogleIdToken('id-token'),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when access_token is an empty string', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope({'access_token': '', 'refresh_token': 'refresh-1'}),
        ),
      );

      await expectLater(
        http.runWithClient(
          () => AuthService().loginWithGoogleIdToken('id-token'),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('loginWithAppleIdToken / loginWithFaceBookIdToken', () {
    test('Apple login hits the apple endpoint', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'access_token': 'a', 'refresh_token': 'r'}),
        );
      });

      await http.runWithClient(
        () => AuthService().loginWithAppleIdToken('apple-token'),
        () => client,
      );
      expect(captured.url.toString(), '$_base/apple');
    });

    test('Facebook login hits the facebook endpoint', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'access_token': 'a', 'refresh_token': 'r'}),
        );
      });

      await http.runWithClient(
        () => AuthService().loginWithFaceBookIdToken('fb-token'),
        () => client,
      );
      expect(captured.url.toString(), '$_base/facebook');
    });
  });

  group('refreshAccessToken', () {
    test('POSTs the refresh_token and returns the new pair', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'access_token': 'new-access', 'refresh_token': 'new-refresh'}),
        );
      });

      final result = await http.runWithClient(
        () => AuthService().refreshAccessToken('old-refresh'),
        () => client,
      );

      expect(result.accessToken, 'new-access');
      expect(result.refreshToken, 'new-refresh');
      expect(captured.url.toString(), '$_base/refresh');
      expect(jsonDecode(captured.body), {'refresh_token': 'old-refresh'});
    });

    test('throws when refresh_token is missing from the response', () async {
      final client = MockClient(
        (request) async =>
            _jsonResponse(_envelope({'access_token': 'new-access'})),
      );

      await expectLater(
        http.runWithClient(
          () => AuthService().refreshAccessToken('old-refresh'),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('logout', () {
    test('POSTs the refresh_token, ignoring the response body', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      });

      await http.runWithClient(
        () => AuthService().logout('some-refresh'),
        () => client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_base/logout');
      expect(jsonDecode(captured.body), {'refresh_token': 'some-refresh'});
    });
  });
}
