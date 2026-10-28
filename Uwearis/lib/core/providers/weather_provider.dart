import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/generated/app_localizations.dart';
import 'locale_provider.dart';
import 'retry_policy.dart';

class WeatherData {
  final String location;
  final double temp;
  final int high;
  final int low;
  final String condition;

  /// Open-Meteo's WMO code for right now; null in a cache written before it
  /// was stored, where [condition] stands in.
  final int? currentCode;
  final bool isDay;
  final List<int> weeklyCodes;
  final List<double> weeklyHighs;
  final List<double> weeklyLows;
  final int timestamp;

  /// Locale [location] was geocoded in; null in a cache written before it
  /// was stored.
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

  late Locale _locale;
  bool _refreshInFlight = false;

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
  Locale _geocodingLocale() => _l10n().localeName.startsWith('zh')
      ? const Locale('zh', 'TW')
      : const Locale('en');

  @override
  Future<WeatherData> build() async {
    _locale = _geocodingLocale();
    final cached = await _loadCache();

    if (cached != null && cached.hasWeeklyData) {
      if (cached.locationLocale != _locale.toLanguageTag()) {
        try {
          return await _fetchFromNetwork(_locale);
        } catch (_) {
          return cached;
        }
      }
      // A Future, not a microtask: runs once build's value is in state.
      if (cached.isStale) Future(refreshIfStale);
      return cached;
    }

    return _fetchFromNetwork(_locale);
  }

  /// Background refresh once the reading is stale (or failed): the old
  /// reading stays on screen meanwhile and if the fetch fails.
  Future<void> refreshIfStale() async {
    if (_refreshInFlight || state.isLoading) return;
    final current = state.value;
    if (current != null && !current.isStale) return;
    _refreshInFlight = true;
    try {
      final fresh = await _fetchFromNetwork(_locale);
      // A locale change rebuilt the provider meanwhile; its own fetch wins.
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {
    } finally {
      _refreshInFlight = false;
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

  Future<WeatherData> _fetchFromNetwork(Locale geocodingLocale) async {
    final pos = await _getLocation();
    final raw = await _fetchWeatherApi(pos.latitude, pos.longitude);
    final locationName = await _getLocationName(
      pos.latitude,
      pos.longitude,
      geocodingLocale,
    );

    final weeklyCodes = List<int>.from(raw['daily']['weathercode']);
    final weeklyHighs = List<double>.from(
      raw['daily']['temperature_2m_max'].map((t) => (t as num).toDouble()),
    );
    final weeklyLows = List<double>.from(
      raw['daily']['temperature_2m_min'].map((t) => (t as num).toDouble()),
    );

    final current = raw['current_weather'] as Map<String, dynamic>;
    final currentCode = (current['weathercode'] as num).toInt();
    final data = WeatherData(
      location: locationName,
      temp: (raw['current_weather']['temperature'] as num).toDouble(),
      high: weeklyHighs.isNotEmpty ? weeklyHighs[0].round() : 0,
      low: weeklyLows.isNotEmpty ? weeklyLows[0].round() : 0,
      condition: WeatherData.conditionFromCode(currentCode),
      currentCode: currentCode,
      // 1 = daytime; absent means daytime too.
      isDay: (current['is_day'] as num?) != 0,
      weeklyCodes: weeklyCodes,
      weeklyHighs: weeklyHighs,
      weeklyLows: weeklyLows,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      locationLocale: geocodingLocale.toLanguageTag(),
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchWeatherApi(double lat, double lon) async {
    final url =
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&daily=weathercode,temperature_2m_max,temperature_2m_min'
        '&current_weather=true&timezone=auto';
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to load weather');
  }

  Future<String> _getLocationName(double lat, double lon, Locale locale) async {
    return await _fetchLocationName(lat, lon, locale) ??
        await _geocodeLocationName(lat, lon, locale) ??
        lookupAppLocalizations(locale).unknownLocation;
  }

  // The platform geocoders ignore the requested locale (Android answers in
  // the system language), so the name comes from an API that honours it.
  Future<String?> _fetchLocationName(
    double lat,
    double lon,
    Locale locale,
  ) async {
    try {
      final language = locale.languageCode == 'zh' ? 'zh-Hant' : 'en';
      final res = await http
          .get(
            Uri.parse(
              'https://api.bigdatacloud.net/data/reverse-geocode-client'
              '?latitude=$lat&longitude=$lon&localityLanguage=$language',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final name = (json.decode(res.body) as Map)['principalSubdivision'];
      return name is String && name.isNotEmpty ? name : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _geocodeLocationName(
    double lat,
    double lon,
    Locale locale,
  ) async {
    try {
      // The plugin sends `toString()` (`zh_TW`), which Android's
      // Locale.forLanguageTag rejects.
      final placemarks = await Geocoding(
        locale: Locale(locale.toLanguageTag()),
      ).placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) return placemarks.first.administrativeArea;
    } catch (_) {}
    return null;
  }
}
