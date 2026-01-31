import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/app_colors.dart';
import 'dart:convert';

class DailyPlannerTab extends StatefulWidget {
  const DailyPlannerTab({super.key});

  @override
  State<DailyPlannerTab> createState() => _DailyPlannerTabState();
}

class _DailyPlannerTabState extends State<DailyPlannerTab> {
  static const Duration _weatherCacheDuration = Duration(minutes: 30);

  String _location = 'Loading...';
  double? _temp;
  int? _high;
  int? _low;
  String _condition = '';
  IconData _weatherIcon = Icons.wb_cloudy_rounded;
  bool _loading = true;
  int _counterValue = 0;

  @override
  void initState() {
    super.initState();
    _loadCachedWeather();
    _refreshWeatherIfNeeded();
  }

  Future<void> _loadCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('cached_weather');

    if (jsonStr == null) return;

    final data = json.decode(jsonStr);
    final cached = CachedWeather.fromJson(data);

    setState(() {
      _location = cached.location;
      _temp = cached.temp;
      _high = cached.high;
      _low = cached.low;
      _condition = cached.condition;
      _weatherIcon = _mapWeatherIcon(_condition);
      _loading = false;
    });
  }

  Future<void> _refreshWeatherIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('cached_weather');

    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = _weatherCacheDuration.inMilliseconds;

    if (jsonStr != null) {
      final cached = CachedWeather.fromJson(json.decode(jsonStr));
      if (now - cached.timestamp < maxAge) {
        return;
      }
    }

    await _fetchAndCacheWeather();
  }

  Future<void> _fetchAndCacheWeather() async {
    try {
      final position = await _getCurrentLocation();
      final data = await _fetchWeather(position.latitude, position.longitude);
      final locationName = await _getLocationName(
        position.latitude,
        position.longitude,
      );

      final cached = CachedWeather(
        location: locationName,
        temp: (data['current_weather']['temperature'] as num).toDouble(),
        high: (data['daily']['temperature_2m_max'][0] as num).round(),
        low: (data['daily']['temperature_2m_min'][0] as num).round(),
        condition: _mapWeatherCode(data['current_weather']['weathercode']),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('cached_weather', json.encode(cached.toJson()));

      if (mounted) {
        setState(() {
          _location = cached.location;
          _temp = cached.temp;
          _high = cached.high;
          _low = cached.low;
          _condition = cached.condition;
          _weatherIcon = _mapWeatherIcon(_condition);
          _loading = false;
        });
      }
    } catch (e) {
      print('Fetch weather failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onRefreshOutfit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating a new look for you...')),
    );
  }

  void _onFeedback(bool liked) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(liked ? 'Glad you like it! ' : 'Got it, we will try something else next time.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _temp == null || _high == null || _low == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WeatherCard(
            location: _location,
            temp: _temp!.round(),
            high: _high!,
            low: _low!,
            condition: _condition,
            icon: _weatherIcon,
          ),
          const SizedBox(height: 20),
          _CounterCard(
            value: _counterValue,
            onIncrement: () {
              setState(() {
                if (_counterValue < 5) _counterValue++;
              });
            },
            onDecrement: () {
              setState(() {
                if (_counterValue > -5) _counterValue--;
              });
            },
          ),
          const SizedBox(height: 20),
          _OutfitTipCard(condition: _condition),
          const SizedBox(height: 20),
          _TodayOutfitIdea(
            onRefresh: _onRefreshOutfit,
            onFeedback: _onFeedback,
          ),
        ],
      ),
    );
  }

  String _mapWeatherCode(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Clouds';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    return 'Clouds';
  }

  Future<Position> _getCurrentLocation() async {
    await Geolocator.requestPermission();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<Map<String, dynamic>> _fetchWeather(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
          '?latitude=$lat'
          '&longitude=$lon'
          '&current_weather=true'
          '&daily=temperature_2m_max,temperature_2m_min'
          '&timezone=Asia%2FTaipei',
    );

    final response = await http.get(url);
    return json.decode(response.body);
  }

  IconData _mapWeatherIcon(String condition) {
    switch (condition) {
      case 'Clear':
        return Icons.wb_sunny_rounded;
      case 'Clouds':
        return Icons.cloud_rounded;
      case 'Rain':
        return Icons.umbrella_rounded;
      case 'Snow':
        return Icons.ac_unit_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  Future<String> _getLocationName(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);

      if (placemarks.isEmpty) return 'Unknown location';

      final place = placemarks.first;
      final district = place.subLocality ?? place.locality ?? '';
      final city = place.administrativeArea ?? '';

      if (district.isNotEmpty && city.isNotEmpty) {
        return '$district, $city';
      }

      return city.isNotEmpty ? city : 'Unknown location';
    } catch (e) {
      print('Reverse geocoding failed: $e');
      return 'Unknown location';
    }
  }
}

class CachedWeather {
  final String location;
  final double temp;
  final int high;
  final int low;
  final String condition;
  final int timestamp;

  CachedWeather({
    required this.location,
    required this.temp,
    required this.high,
    required this.low,
    required this.condition,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'location': location,
    'temp': temp,
    'high': high,
    'low': low,
    'condition': condition,
    'timestamp': timestamp,
  };

  static CachedWeather fromJson(Map<String, dynamic> json) {
    return CachedWeather(
      location: json['location'],
      temp: json['temp'],
      high: json['high'],
      low: json['low'],
      condition: json['condition'],
      timestamp: json['timestamp'],
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final String _location;
  final int _temp;
  final int _high;
  final int _low;
  final String _condition;
  final IconData _icon;

  const _WeatherCard({
    required String location,
    required int temp,
    required int high,
    required int low,
    required String condition,
    required IconData icon,
  }) : _icon = icon, _condition = condition, _low = low, _high = high, _temp = temp, _location = location;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_icon, size: 48, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _location,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_condition · H:$_high°  L:$_low°',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$_temp°',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CounterCard({
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Adjust perceived temperature",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
          ),
          SizedBox(
            width: 50,
            child: Center(
              child: Text(
                value >= 0 ? "+${value}°" : "${value}°",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OutfitTipCard extends StatelessWidget {
  final String _condition;

  const _OutfitTipCard({required String condition}) : _condition = condition;

  String get tip {
    switch (_condition) {
      case 'Rain':
        return 'It’s rainy today.\nWaterproof shoes are recommended.';
      case 'Clear':
        return 'Sunny day!\nLight layers work great.';
      case 'Clouds':
        return 'Cloudy and mild.\nComfortable casual wear is perfect.';
      case 'Snow':
        return 'Cold weather.\nWarm jacket and boots are a must.';
      default:
        return 'Dress comfortably for today.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayOutfitIdea extends StatelessWidget {
  final VoidCallback onRefresh;
  final Function(bool) onFeedback;

  const _TodayOutfitIdea({
    required this.onRefresh,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Outfit',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text(
                'New Look',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    color: AppColors.border.withOpacity(0.2),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Best Match for Today',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onFeedback(false),
                icon: const Icon(Icons.thumb_down_outlined, size: 18),
                label: const Text('Dislike'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onFeedback(true),
                icon: const Icon(Icons.thumb_up_outlined, size: 18),
                label: const Text('Like'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}