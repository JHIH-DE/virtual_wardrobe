import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis_cms/api/api_client.dart';
import 'package:uwearis_cms/widgets/feedback.dart';

http.Response _json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _ok(Object? data) => {
  'success': true,
  'message': 'ok',
  'error_code': null,
  'data': data,
};

Future<ApiClient> _signedIn(MockClient mock) async {
  final client = ApiClient(httpClient: mock);
  await client.signInWithGoogle('google-id-token');
  client.confirmSession(1);
  return client;
}

void main() {
  test('only counts as signed in once the session is confirmed', () async {
    final client = ApiClient(
      httpClient: MockClient(
        (_) async =>
            _json(200, _ok({'access_token': 'a1', 'refresh_token': 'r1'})),
      ),
    );
    await client.signInWithGoogle('t');
    expect(client.isSignedIn, isFalse);
    client.confirmSession(1);
    expect(client.isSignedIn, isTrue);
    client.signOut();
    expect(client.isSignedIn, isFalse);
  });

  test('a business error carries the backend code and message', () async {
    final client = await _signedIn(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/google')) {
          return _json(200, _ok({'access_token': 'a1', 'refresh_token': 'r1'}));
        }
        return _json(409, {
          'success': false,
          'message': '網址代稱 x 已被使用',
          'error_code': 'MAGAZINE_SLUG_TAKEN',
          'data': null,
        });
      }),
    );
    await expectLater(
      client.post('/admin/magazine/issues', {'slug': 'x'}),
      throwsA(
        isA<ApiError>()
            .having((e) => e.errorCode, 'code', 'MAGAZINE_SLUG_TAKEN')
            .having((e) => e.message, 'message', '網址代稱 x 已被使用'),
      ),
    );
  });

  test('a 422 names the failing field', () async {
    final client = await _signedIn(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/google')) {
          return _json(200, _ok({'access_token': 'a1', 'refresh_token': 'r1'}));
        }
        return _json(422, {
          'detail': [
            {
              'loc': ['body', 'slug'],
              'msg': 'String should match pattern',
            },
          ],
        });
      }),
    );
    await expectLater(
      client.post('/admin/magazine/issues', {}),
      throwsA(
        isA<ApiError>().having((e) => e.message, 'message', contains('slug')),
      ),
    );
  });

  test('a 401 refreshes once, then retries with the new token', () async {
    final seen = <String>[];
    final client = await _signedIn(
      MockClient((req) async {
        final path = req.url.path;
        seen.add('$path ${req.headers['Authorization'] ?? ''}'.trim());
        if (path.endsWith('/auth/google')) {
          return _json(200, _ok({'access_token': 'a1', 'refresh_token': 'r1'}));
        }
        if (path.endsWith('/auth/refresh')) {
          return _json(200, _ok({'access_token': 'a2', 'refresh_token': 'r2'}));
        }
        return req.headers['Authorization'] == 'Bearer a2'
            ? _json(200, _ok([]))
            : _json(401, {'detail': 'expired'});
      }),
    );
    expect(await client.get('/admin/magazine/issues'), isEmpty);
    expect(seen, [
      '/api/v1/auth/google',
      '/api/v1/admin/magazine/issues Bearer a1',
      '/api/v1/auth/refresh',
      '/api/v1/admin/magazine/issues Bearer a2',
    ]);
    expect(client.isSignedIn, isTrue);
  });

  test('a failed refresh ends the session', () async {
    var refreshes = 0;
    final client = await _signedIn(
      MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/auth/google')) {
          return _json(200, _ok({'access_token': 'a1', 'refresh_token': 'r1'}));
        }
        if (path.endsWith('/auth/refresh')) {
          refreshes++;
          return _json(401, {'detail': 'revoked'});
        }
        if (path.endsWith('/auth/logout')) return _json(200, _ok(null));
        return _json(401, {'detail': 'expired'});
      }),
    );
    await expectLater(
      client.get('/admin/magazine/issues'),
      throwsA(isA<ApiError>()),
    );
    expect(refreshes, 1);
    expect(client.isSignedIn, isFalse);
  });

  test('a server error carries its request id for reporting', () async {
    final client = await _signedIn(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/google')) {
          return _json(200, _ok({'access_token': 'a1', 'refresh_token': 'r1'}));
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': false,
              'message': '伺服器發生錯誤',
              'error_code': 'INTERNAL_ERROR',
              'data': null,
            }),
          ),
          500,
          headers: {
            'content-type': 'application/json',
            'x-request-id': 'req-123',
          },
        );
      }),
    );
    try {
      await client.get('/admin/users');
      fail('expected an ApiError');
    } on ApiError catch (e) {
      expect(e.requestId, 'req-123');
      expect(errorText(e), contains('req-123'));
    }
  });
}
