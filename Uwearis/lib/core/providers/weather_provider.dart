import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/generated/app_localizations.dart';
import '../services/weather_service.dart';
import 'locale_provider.dart';
import 'retry_policy.dart';

class WeatherData {
  final String location;
  final double temp;
  final int high;
  final int low;
  final String condition;

  /// The WMO weather code for right now; null when the backend has none or
  /// in a cache written before it was stored, where [condition] stands in.
  final int? currentCode;
  final bool isDay;
  final List<int> weeklyCodes;
  final List<double> weeklyHighs;
  final List<double> weeklyLows;
  final int timestamp;

  /// App locale [location] was fetched under; null in a cache written
  /// before it was stored.
  final String? locationLocale;

  const WeatherData({
    required this.location,
    required this.temp,
    required this.high,
    required this.low,
    required this.condition,
    this.currentCode,
    this.isDay = true,
    required this.weeklyCodes,
    required this.weeklyHighs,
    required this.weeklyLows,
    required this.timestamp,
    this.locationLocale,
  });

  bool get isStale =>
      DateTime.now().millisecondsSinceEpoch - timestamp >
      const Duration(minutes: 30).inMilliseconds;

  bool get hasWeeklyData =>
      weeklyCodes.isNotEmpty && weeklyHighs.isNotEmpty && weeklyLows.isNotEmpty;

  /// Mean of today's forecast high and low (what the backend's daily
  /// outfits use); the current reading if there's no forecast.
  double get todayMeanTemp => weeklyHighs.isNotEmpty && weeklyLows.isNotEmpty
      ? (weeklyHighs.first + weeklyLows.first) / 2
      : temp;

  static String conditionFromCode(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Clouds';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    return 'Clouds';
  }

  /// The Meteocons illustration for a WMO weather code.
  static String iconAssetFor(int code, {required bool isDay}) {
    final name = switch (code) {
      0 => isDay ? 'clear-day' : 'clear-night',
      1 || 2 => isDay ? 'partly-cloudy-day' : 'partly-cloudy-night',
      45 || 48 => 'fog',
      >= 51 && <= 57 => 'drizzle',
      (>= 61 && <= 67) || (>= 80 && <= 82) => 'rain',
      (>= 71 && <= 77) || 85 || 86 => 'snow',
      >= 95 && <= 99 => 'thunderstorms-rain',
      _ => 'overcast',
    };
    return 'assets/images/weather/$name.svg';
  }

  String get iconAsset => iconAssetFor(
    currentCode ??
        switch (condition) {
          'Clear' => 0,
          'Rain' => 61,
          'Snow' => 71,
          _ => 3,
        },
    isDay: isDay,
  );

  /// Parses `GET /weather`'s `data`. A null `location_name` (reverse
  /// geocoding failed) shows as [unknownLocation].
  factory WeatherData.fromApi(
    Map<String, dynamic> data, {
    required String unknownLocation,
    required String locationLocale,
  }) {
    final current = data['current'] is Map<String, dynamic>
        ? data['current'] as Map<String, dynamic>
        : const <String, dynamic>{};
    // Stop at the first day without both temperatures, so the lists stay
    // parallel and index 0 is still today.
    final days = (data['daily'] as List? ?? const [])
        .takeWhile(
          (d) =>
              d is Map &&
              d['temperature_max_c'] is num &&
              d['temperature_min_c'] is num,
        )
        .cast<Map>()
        .toList();
    final weeklyHighs = [
      for (final d in days) (d['temperature_max_c'] as num).toDouble(),
    ];
    final weeklyLows = [
      for (final d in days) (d['temperature_min_c'] as num).toDouble(),
    ];
    final weeklyCodes = [
      for (final d in days) (d['weather_code'] as num?)?.toInt() ?? 3,
    ];

    final currentCode = (current['weather_code'] as num?)?.toInt();
    final temp =
        (current['temperature_c'] as num?)?.toDouble() ??
        (days.isEmpty ? null : (weeklyHighs.first + weeklyLows.first) / 2);
    if (temp == null) {
      throw const FormatException('getWeather: no temperature in response');
    }
    final name = data['location_name'];
    return WeatherData(
      location: name is String && name.isNotEmpty ? name : unknownLocation,
      temp: temp,
      high: (days.isEmpty ? temp : weeklyHighs.first).round(),
      low: (days.isEmpty ? temp : weeklyLows.first).round(),
      condition: currentCode == null
          ? 'Clouds'
          : conditionFromCode(currentCode),
      currentCode: currentCode,
      isDay: current['is_day'] as bool? ?? true,
      weeklyCodes: weeklyCodes,
      weeklyHighs: weeklyHighs,
      weeklyLows: weeklyLows,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      locationLocale: locationLocale,
    );
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    location: json['location'] as String,
    temp: (json['temp'] as num).toDouble(),
    high: json['high'] as int,
    low: json['low'] as int,
    condition: json['condition'] as String,
    currentCode: (json['currentCode'] as num?)?.toInt(),
    isDay: json['isDay'] as bool? ?? true,
    weeklyCodes: List<int>.from(json['weeklyCodes'] ?? []),
    weeklyHighs: List<double>.from(
      (json['weeklyHighs'] ?? []).map((t) => (t as num).toDouble()),
    ),
    weeklyLows: List<double>.from(
      (json['weeklyLows'] ?? []).map((t) => (t as num).toDouble()),
    ),
    timestamp: json['timestamp'] as int,
    locationLocale: json['locationLocale'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'location': location,
    'temp': temp,
    'high': high,
    'low': low,
    'condition': condition,
    'currentCode': currentCode,
    'isDay': isDay,
    'weeklyCodes': weeklyCodes,
    'weeklyHighs': weeklyHighs,
    'weeklyLows': weeklyLows,
    'timestamp': timestamp,
    'locationLocale': locationLocale,
  };
}

final weatherProvider = AsyncNotifierProvider<WeatherNotifier, WeatherData>(
  WeatherNotifier.new,
  retry: appRetryPolicy,
);

class WeatherNotifier extends AsyncNotifier<WeatherData> {
  // v2: earlier caches hold place names in the device language, whatever
  // their `locationLocale` says.
  static const String _cacheKey = 'cached_weather_v2';

  /// Session-end only: the place name may come from the previous
  /// account's profile location.
  static Future<void> clearCache() async {
    // Before any await, so a reading still in flight can't be written back
    // after the removal.
    _cacheEpoch++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  // Bumped by [clearCache]. Sign-out doesn't rebuild this provider (that
  // happens at the next sign-in), so [_generation] alone can't stop a
  // reading the previous account requested from being cached.
  static int _cacheEpoch = 0;

  // Riverpod keeps this notifier across invalidate and locale rebuilds, and
  // `ref` is always the newest build's, so `ref.mounted` can't tell a reply
  // to an earlier generation from a current one. Bumped on every
  // dispose/rebuild; work from another generation touches nothing.
  int _generation = 0;

  bool _isCurrent(int generation) => generation == _generation;

  late Locale _locale;

  // The generation whose background refresh is in flight, so an older
  // generation's neither blocks nor (finishing) unblocks a newer one's.
  int? _refreshInFlightFor;

  // No BuildContext here: the language override, else the device locale.
  AppLocalizations _l10n() {
    final locale =
        ref.watch(localeProvider) ?? PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  // The app's `zh` strings are Traditional, so any Chinese maps to zh_TW.
  Locale _weatherLocale() => _l10n().localeName.startsWith('zh')
      ? const Locale('zh', 'TW')
      : const Locale('en');

  @override
  Future<WeatherData> build() async {
    final generation = _generation;
    ref.onDispose(() => _generation++);
    _locale = _weatherLocale();
    final cached = await _loadCache();

    if (cached != null && cached.hasWeeklyData) {
      if (cached.locationLocale != _locale.toLanguageTag()) {
        try {
          return await _fetchFromNetwork(_locale, generation);
        } catch (_) {
          return cached;
        }
      }
      // A Future, not a microtask: runs once build's value is in state.
      // Skipped if this generation is gone by then (its state with it).
      if (cached.isStale) {
        Future(() {
          if (_isCurrent(generation)) refreshIfStale();
        });
      }
      return cached;
    }

    return _fetchFromNetwork(_locale, generation);
  }

  /// Background refresh once the reading is stale (or failed): the old
  /// reading stays on screen meanwhile and if the fetch fails.
  Future<void> refreshIfStale() async {
    final generation = _generation;
    if (_refreshInFlightFor == generation || state.isLoading) return;
    final current = state.value;
    if (current != null && !current.isStale) return;
    _refreshInFlightFor = generation;
    try {
      final fresh = await _fetchFromNetwork(_locale, generation);
      // A sign-in or locale change rebuilt the provider meanwhile; its own
      // fetch wins.
      if (_isCurrent(generation)) state = AsyncData(fresh);
    } catch (_) {
    } finally {
      if (_refreshInFlightFor == generation) _refreshInFlightFor = null;
    }
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

  /// Caches the reading only while [generation] is current and no
  /// [clearCache] has run since the request started.
  Future<WeatherData> _fetchFromNetwork(Locale locale, int generation) async {
    final cacheEpoch = _cacheEpoch;
    // The backend names the place in the profile's `locale`; a language
    // switch PATCHes it, so wait for that before asking.
    await ref.read(localeProvider.notifier).backendSynced;
    // No position (services off, permission denied, timeout) isn't an
    // error: without coordinates the backend uses the profile's location.
    Position? pos;
    try {
      pos = await _getLocation();
    } catch (_) {}
    final raw = await WeatherService().getWeather(
      lat: pos?.latitude,
      lon: pos?.longitude,
    );
    final data = WeatherData.fromApi(
      raw,
      unknownLocation: lookupAppLocalizations(locale).unknownLocation,
      locationLocale: locale.toLanguageTag(),
    );

    final prefs = await SharedPreferences.getInstance();
    // Checked after the last await: setString updates the in-memory copy
    // synchronously, so a clearCache can't slip in between.
    if (_isCurrent(generation) && cacheEpoch == _cacheEpoch) {
      await prefs.setString(_cacheKey, json.encode(data.toJson()));
    }
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      ),
    );
  }
}
