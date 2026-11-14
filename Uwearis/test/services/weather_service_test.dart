import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/weather_service.dart';

import '../helpers/fake_auth.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/weather';

http.Response _json(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(setUpFakeAuth);

  test('sends coordinates rounded to 2 decimals and returns data', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return _json({
        'success': true,
        'data': {'location_name': '臺北市'},
      });
    });

    final data = await http.runWithClient(
      () => WeatherService().getWeather(lat: 25.03789, lon: 121.56441),
      () => client,
    );

    expect(captured.method, 'GET');
    expect(captured.url.toString(), '$_base?lat=25.04&lon=121.56');
    expect(captured.headers['Authorization'], startsWith('Bearer '));
    expect(data['location_name'], '臺北市');
  });

  test('sends no query without a position', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return _json({'success': true, 'data': <String, dynamic>{}});
    });

    await http.runWithClient(() => WeatherService().getWeather(), () => client);

    expect(captured.url.toString(), _base);
  });

  test('a backend error surfaces as ApiException with its code', () async {
    final client = MockClient(
      (_) async => _json({
        'success': false,
        'message': 'no location',
        'error_code': 'WEATHER_LOCATION_REQUIRED',
        'data': null,
      }, status: 400),
    );

    await expectLater(
      http.runWithClient(() => WeatherService().getWeather(), () => client),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having(
              (e) => e.errorCode,
              'errorCode',
              'WEATHER_LOCATION_REQUIRED',
            ),
      ),
    );
  });
}
