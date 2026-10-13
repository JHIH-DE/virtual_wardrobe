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
}
