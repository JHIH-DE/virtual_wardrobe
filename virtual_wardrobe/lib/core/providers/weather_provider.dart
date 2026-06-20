import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherData {
  final String location;
  final double temp;
  final int high;
  final int low;
  final String condition;
  final List<int> weeklyCodes;
  final List<double> weeklyHighs;
  final List<double> weeklyLows;
  final int timestamp;

  const WeatherData({
    required this.location,
    required this.temp,
    required this.high,
    required this.low,
    required this.condition,
    required this.weeklyCodes,
    required this.weeklyHighs,
    required this.weeklyLows,
    required this.timestamp,
  });

  bool get isStale =>
      DateTime.now().millisecondsSinceEpoch - timestamp >
      const Duration(minutes: 30).inMilliseconds;

  bool get hasWeeklyData =>
      weeklyCodes.isNotEmpty && weeklyHighs.isNotEmpty && weeklyLows.isNotEmpty;

  static String conditionFromCode(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Clouds';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    return 'Clouds';
  }

  static IconData iconFromCondition(String condition) {
    switch (condition) {
      case 'Clear':
        return Icons.wb_sunny_rounded;
      case 'Rain':
        return Icons.umbrella_rounded;
      case 'Snow':
        return Icons.ac_unit_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        location: json['location'] as String,
        temp: (json['temp'] as num).toDouble(),
        high: json['high'] as int,
        low: json['low'] as int,
        condition: json['condition'] as String,
        weeklyCodes: List<int>.from(json['weeklyCodes'] ?? []),
        weeklyHighs: List<double>.from(
            (json['weeklyHighs'] ?? []).map((t) => (t as num).toDouble())),
        weeklyLows: List<double>.from(
            (json['weeklyLows'] ?? []).map((t) => (t as num).toDouble())),
        timestamp: json['timestamp'] as int,
      );

  Map<String, dynamic> toJson() => {
        'location': location,
        'temp': temp,
        'high': high,
        'low': low,
        'condition': condition,
        'weeklyCodes': weeklyCodes,
        'weeklyHighs': weeklyHighs,
        'weeklyLows': weeklyLows,
        'timestamp': timestamp,
      };
}

final weatherProvider =
    AsyncNotifierProvider<WeatherNotifier, WeatherData>(WeatherNotifier.new);

class WeatherNotifier extends AsyncNotifier<WeatherData> {
  static const String _cacheKey = 'cached_weather';

  @override
  Future<WeatherData> build() async {
    final cached = await _loadCache();

    if (cached != null && cached.hasWeeklyData) {
      if (cached.isStale) {
        // 背景更新，不阻塞 UI
        Future.microtask(() async {
          try {
            final fresh = await _fetchFromNetwork();
            state = AsyncData(fresh);
          } catch (_) {}
        });
      }
      return cached;
    }

    return _fetchFromNetwork();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchFromNetwork);
  }

  Future<WeatherData?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null) return null;
      return WeatherData.fromJson(json.decode(jsonStr));
    } catch (_) {
      return null;
    }
  }

  Future<WeatherData> _fetchFromNetwork() async {
    final pos = await _getLocation();
    final raw = await _fetchWeatherApi(pos.latitude, pos.longitude);
    final locationName = await _getLocationName(pos.latitude, pos.longitude);

    final weeklyCodes = List<int>.from(raw['daily']['weathercode']);
    final weeklyHighs = List<double>.from(
        raw['daily']['temperature_2m_max'].map((t) => (t as num).toDouble()));
    final weeklyLows = List<double>.from(
        raw['daily']['temperature_2m_min'].map((t) => (t as num).toDouble()));

    final data = WeatherData(
      location: locationName,
      temp: (raw['current_weather']['temperature'] as num).toDouble(),
      high: weeklyHighs.isNotEmpty ? weeklyHighs[0].round() : 0,
      low: weeklyLows.isNotEmpty ? weeklyLows[0].round() : 0,
      condition: WeatherData.conditionFromCode(raw['current_weather']['weathercode']),
      weeklyCodes: weeklyCodes,
      weeklyHighs: weeklyHighs,
      weeklyLows: weeklyLows,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, json.encode(data.toJson()));
    return data;
  }

  Future<Position> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 5),
    );
  }

  Future<Map<String, dynamic>> _fetchWeatherApi(double lat, double lon) async {
    final url =
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&daily=weathercode,temperature_2m_max,temperature_2m_min'
        '&current_weather=true&timezone=auto';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to load weather');
  }

  Future<String> _getLocationName(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        return placemarks.first.administrativeArea ?? 'Unknown Location';
      }
    } catch (_) {}
    return 'Unknown Location';
  }
}
