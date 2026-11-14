import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/weather_provider.dart';

WeatherData _weather({
  double temp = 30,
  List<double> highs = const [],
  List<double> lows = const [],
}) => WeatherData(
  location: 'Test City',
  temp: temp,
  high: 0,
  low: 0,
  condition: 'Clear',
  weeklyCodes: const [],
  weeklyHighs: highs,
  weeklyLows: lows,
  timestamp: 0,
);

void main() {
  group('todayMeanTemp', () {
    test("averages today's forecast high and low, not the current reading", () {
      final weather = _weather(highs: [27.4, 31], lows: [18.6, 20]);
      expect(weather.todayMeanTemp, closeTo(23, 0.001));
    });

    test("falls back to the current reading without today's forecast", () {
      expect(_weather(temp: 25.5).todayMeanTemp, 25.5);
    });
  });

  group('iconAsset', () {
    String icon(int code, {bool isDay = true}) =>
        WeatherData.iconAssetFor(code, isDay: isDay).split('/').last;

    test('maps WMO codes, including showers, fog and thunderstorms', () {
      expect(icon(0), 'clear-day.svg');
      expect(icon(2), 'partly-cloudy-day.svg');
      expect(icon(3), 'overcast.svg');
      expect(icon(45), 'fog.svg');
      expect(icon(53), 'drizzle.svg');
      expect(icon(63), 'rain.svg');
      expect(icon(81), 'rain.svg');
      expect(icon(75), 'snow.svg');
      expect(icon(86), 'snow.svg');
      expect(icon(95), 'thunderstorms-rain.svg');
    });

    test('every code maps to an illustration that ships with the app', () {
      for (final isDay in [true, false]) {
        for (var code = 0; code <= 99; code++) {
          final path = WeatherData.iconAssetFor(code, isDay: isDay);
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    });

    test('a clear or partly cloudy night shows the moon', () {
      expect(icon(0, isDay: false), 'clear-night.svg');
      expect(icon(1, isDay: false), 'partly-cloudy-night.svg');
      expect(icon(61, isDay: false), 'rain.svg');
    });

    test('a cache from before the code was stored falls back to its '
        'condition, as daytime', () {
      final json = _weather().toJson()
        ..remove('currentCode')
        ..remove('isDay')
        ..['condition'] = 'Rain';
      final cached = WeatherData.fromJson(json);
      expect(cached.isDay, isTrue);
      expect(cached.iconAsset.split('/').last, 'rain.svg');
    });

    test('code and day/night survive the cache round trip', () {
      final weather = WeatherData(
        location: 'Test City',
        temp: 12,
        high: 15,
        low: 9,
        condition: 'Clouds',
        currentCode: 2,
        isDay: false,
        weeklyCodes: const [2],
        weeklyHighs: const [15],
        weeklyLows: const [9],
        timestamp: 0,
      );
      final restored = WeatherData.fromJson(weather.toJson());
      expect(restored.iconAsset.split('/').last, 'partly-cloudy-night.svg');
    });
  });

  group('fromApi', () {
    WeatherData parse(Map<String, dynamic> data) => WeatherData.fromApi(
      data,
      unknownLocation: 'Unknown location',
      locationLocale: 'zh-TW',
    );

    test('maps the documented response', () {
      final w = parse({
        'location_name': '臺北市',
        'location_source': 'gps',
        'current': {'temperature_c': 28.1, 'weather_code': 53, 'is_day': false},
        'daily': [
          {
            'date': '2026-11-14',
            'weather_code': 81,
            'temperature_max_c': 29.6,
            'temperature_min_c': 20.2,
          },
          {
            'date': '2026-11-15',
            'weather_code': 0,
            'temperature_max_c': 27.0,
            'temperature_min_c': 19.0,
          },
        ],
      });

      expect(w.location, '臺北市');
      expect(w.temp, 28.1);
      expect(w.currentCode, 53);
      expect(w.condition, 'Rain');
      expect(w.isDay, isFalse);
      expect(w.high, 30);
      expect(w.low, 20);
      expect(w.weeklyCodes, [81, 0]);
      expect(w.weeklyHighs, [29.6, 27.0]);
      expect(w.weeklyLows, [20.2, 19.0]);
      expect(w.locationLocale, 'zh-TW');
    });

    test('a null place name shows as unknown location', () {
      final w = parse({
        'location_name': null,
        'current': {'temperature_c': 20, 'weather_code': 0, 'is_day': true},
        'daily': const [],
      });
      expect(w.location, 'Unknown location');
    });

    test('null fields fall back without breaking the forecast lists', () {
      final w = parse({
        'location_name': 'Taipei',
        'current': {
          'temperature_c': null,
          'weather_code': null,
          'is_day': true,
        },
        'daily': [
          {
            'weather_code': null,
            'temperature_max_c': 30,
            'temperature_min_c': 20,
          },
          {
            'weather_code': 1,
            'temperature_max_c': null,
            'temperature_min_c': 18,
          },
          {'weather_code': 2, 'temperature_max_c': 26, 'temperature_min_c': 17},
        ],
      });

      // Today's mean stands in for the current reading; the forecast stops
      // at the first day missing a temperature.
      expect(w.temp, 25);
      expect(w.currentCode, isNull);
      expect(w.weeklyCodes, [3]);
      expect(w.weeklyHighs, [30]);
      expect(w.weeklyLows, [20]);
    });

    test('a response without any temperature is rejected', () {
      expect(
        () => parse({
          'location_name': 'Taipei',
          'current': {'temperature_c': null},
          'daily': const [],
        }),
        throwsFormatException,
      );
    });
  });
}
