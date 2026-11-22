import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/background_service.dart';

import '../helpers/fake_auth.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/backgrounds';

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
  setUp(setUpFakeAuth);

  test('GETs /backgrounds and keeps the order it was sent in', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return _jsonResponse(
        _envelope([
          {
            'id': 0,
            'name': 'default_fitting_room',
            'scene_description': '試衣間',
            'sort_order': 0,
            'image_url': 'https://storage.example/0.jpg',
            'image_cache_key': 'key0',
            'created_at': '2026-08-08T21:23:36',
          },
          {
            'id': 8.0,
            'name': 'coffeehouse',
            'sort_order': 10,
            'image_url': null,
            'image_cache_key': null,
          },
          {'name': 'no_id'},
          'not a map',
          {'id': 7, 'name': 'tokyo_street', 'sort_order': 20},
        ]),
      );
    });

    final backgrounds = await http.runWithClient(
      () => BackgroundService().getBackgrounds(),
      () => client,
    );

    expect(captured.method, 'GET');
    expect(captured.url.toString(), _base);
    expect([for (final b in backgrounds) b.id], [0, 8, 7]);
    expect(backgrounds[0].imageUrl, 'https://storage.example/0.jpg');
    expect(backgrounds[0].imageCacheKey, 'key0');
    expect(backgrounds[1].imageUrl, isNull);
    expect(backgrounds[1].imageCacheKey, isNull);
  });

  test('a non-2xx response throws ApiException', () async {
    final client = MockClient(
      (_) async => _jsonResponse({'success': false}, status: 500),
    );
    await expectLater(
      http.runWithClient(
        () => BackgroundService().getBackgrounds(),
        () => client,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
