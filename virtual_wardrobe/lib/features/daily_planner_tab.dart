import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/app_colors.dart';
import '../core/services/error_handler.dart';
import '../core/services/weekly_plans_service.dart';
import '../core/services/outfit_service.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/garment_category.dart';
import '../data/look_category.dart';

class DailyPlannerTab extends StatefulWidget {
  const DailyPlannerTab({super.key});

  @override
  State<DailyPlannerTab> createState() => _DailyPlannerTabState();
}

class _DailyPlannerTabState extends State<DailyPlannerTab> with TryOnMixin {
  static const Duration _weatherCacheDuration = Duration(minutes: 30);

  String _location = 'Loading...';
  double? _temp;
  int? _high;
  int? _low;
  String _condition = '';
  IconData _weatherIcon = Icons.wb_cloudy_rounded;
  bool _loading = true;
  int _counterValue = 0;

  // 週計畫相關狀態
  List<String> _weeklyOccasions = List.generate(7, (_) => 'casual_daily');
  List<int> _weeklyWeatherCodes = [];
  List<double> _weeklyHighTemps = [];
  List<double> _weeklyLowTemps = [];

  // 當日衣服資訊
  List<Garment> _todayGarments = [];
  bool _loadingOutfits = false;
  int _selectedDayIndex = 0;
  String? _todayLookImageUrl;

  final Map<String, String> _occasionLabels = {
    'casual_daily': '🏠 Daily',
    'work': '💼 Work',
    'date': '❤️ Date',
    'sport': '🏃 Sport',
    'formal': '👔 Formal',
  };

  @override
  void initState() {
    super.initState();
    _fullInit();
  }

  Future<void> _fullInit() async {
    setState(() => _loading = true);
    try {
      await _initOccasions();
      await _loadCachedWeather();
      await _refreshWeatherIfNeeded(_loading);

      if (_weeklyHighTemps.isNotEmpty) {
        await _createWeeklyPlan();
      }
      await _loadDailyData();
      
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initOccasions() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSavedDate = prefs.getString('occasions_last_saved');
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastSavedDate == todayStr) {
      final saved = prefs.getStringList('weekly_occasions');
      if (saved != null && saved.length == 7) {
        setState(() => _weeklyOccasions = saved);
        return;
      }
    }

    List<String> newOccasions = [];
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().add(Duration(days: i));
      if (date.weekday >= DateTime.monday && date.weekday <= DateTime.friday) {
        newOccasions.add('work');
      } else {
        newOccasions.add('casual_daily');
      }
    }

    setState(() => _weeklyOccasions = newOccasions);
    await _saveOccasions();
  }

  Future<void> _saveOccasions() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setStringList('weekly_occasions', _weeklyOccasions);
    await prefs.setString('occasions_last_saved', todayStr);
  }

  Future<void> _loadDailyData() async {
    await _getGarments(daysFromNow: _selectedDayIndex);
    await _getOutfits(daysFromNow: _selectedDayIndex);
  }

  Future<void> _loadCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('cached_weather');
    if (jsonStr == null) return;

    try {
      final data = json.decode(jsonStr);
      final cached = CachedWeather.fromJson(data);
      setState(() {
        _location = cached.location;
        _temp = cached.temp;
        _high = cached.high;
        _low = cached.low;
        _condition = cached.condition;
        _weatherIcon = _mapWeatherIcon(_condition);
        if (cached.weeklyWeatherCodes != null) {
          _weeklyWeatherCodes = cached.weeklyWeatherCodes!;
          _weeklyHighTemps = cached.weeklyMaxTemps!;
          _weeklyLowTemps = cached.weeklyMinTemps ?? [];
        }
      });
    } catch (e) {
      debugPrint('Error loading cached weather: $e');
    }
  }

  Future<void> _refreshWeatherIfNeeded(bool isLoaded) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('cached_weather');
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = _weatherCacheDuration.inMilliseconds;

    Position? currentPos;
    try {
      currentPos = await _getCurrentLocation();
    } catch (e) {
      debugPrint('Location access failed: $e');
    }

    if (isLoaded && jsonStr != null) {
      try {
        final cached = CachedWeather.fromJson(json.decode(jsonStr));
        bool isTimeExpired = (now - cached.timestamp >= maxAge);
        bool isDataMissing = cached.weeklyMinTemps == null || cached.weeklyMaxTemps == null;
        if (!isTimeExpired && !isDataMissing) return;
      } catch (e) {
        debugPrint('Error checking weather cache: $e');
      }
    }
    await _fetchAndCacheWeather(currentPos);
  }

  Future<void> _fetchAndCacheWeather([Position? position]) async {
    try {
      final pos = position ?? await _getCurrentLocation();
      final data = await _fetchWeather(pos.latitude, pos.longitude);
      final locationName = await _getLocationName(pos.latitude, pos.longitude);

      final weeklyCodes = List<int>.from(data['daily']['weathercode']);
      final weeklyMaxs = List<double>.from(data['daily']['temperature_2m_max'].map((t) => (t as num).toDouble()));
      final weeklyMins = List<double>.from(data['daily']['temperature_2m_min'].map((t) => (t as num).toDouble()));

      final cached = CachedWeather(
        location: locationName,
        temp: (data['current_weather']['temperature'] as num).toDouble(),
        high: weeklyMaxs.isNotEmpty ? weeklyMaxs[0].round() : 0,
        low: weeklyMins.isNotEmpty ? weeklyMins[0].round() : 0,
        condition: _mapWeatherCode(data['current_weather']['weathercode']),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        lat: pos.latitude,
        lon: pos.longitude,
        weeklyWeatherCodes: weeklyCodes,
        weeklyMaxTemps: weeklyMaxs,
        weeklyMinTemps: weeklyMins,
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
          _weeklyWeatherCodes = weeklyCodes;
          _weeklyHighTemps = weeklyMaxs;
          _weeklyLowTemps = weeklyMins;
        });
      }
    } catch (e) {
      debugPrint('Fetch weather failed: $e');
    }
  }

  void _showPlanSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  const Text("Plan Customization", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildSectionTitle("Comfort Adjustment"),
                        const SizedBox(height: 12),
                        _buildTempAdjuster(setModalState),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Daily Occasions"),
                        const SizedBox(height: 8),
                        ...(List.generate(7, (index) => index).toList()
                              ..sort((a, b) => DateTime.now()
                                  .add(Duration(days: a))
                                  .weekday
                                  .compareTo(DateTime.now()
                                      .add(Duration(days: b))
                                      .weekday)))
                            .map((index) {
                          final date = DateTime.now().add(Duration(days: index));
                          final isToday = index == 0;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isToday
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.1),
                              child: Text(DateFormat('E').format(date)[0],
                                  style: TextStyle(
                                      color: isToday
                                          ? Colors.white
                                          : AppColors.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(
                                isToday
                                    ? "${DateFormat('EEEE').format(date)} (Today)"
                                    : DateFormat('EEEE').format(date),
                                style: TextStyle(
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            trailing: DropdownButton<String>(
                              value: _weeklyOccasions[index],
                              underline: const SizedBox(),
                              items: _occasionLabels.entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(
                                      () => _weeklyOccasions[index] = val);
                                  setState(() {}); // 同步更新主畫面
                                  _saveOccasions();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: () async {
                        await _createWeeklyPlan();
                        await _loadDailyData();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan updated based on your settings')));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Apply", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary));
  }

  Widget _buildTempAdjuster(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(child: Text("Perceived temperature offset", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          IconButton(
            onPressed: () {
              if (_counterValue > -5) {
                setModalState(() => _counterValue--);
                setState(() {});
              }
            },
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${_counterValue > 0 ? "+" : ""}$_counterValue°',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          IconButton(
            onPressed: () {
              if (_counterValue < 5) {
                setModalState(() => _counterValue++);
                setState(() {});
              }
            },
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _temp == null || _weeklyHighTemps.isEmpty || _weeklyLowTemps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_location, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text(DateFormat('MMMM d, EEEE').format(DateTime.now()), style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              IconButton(
                onPressed: _showPlanSettings,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWeeklyWeatherBar(),
          const SizedBox(height: 20),
          _buildWardrobeSection(),
          const SizedBox(height: 20),
          _TodayOutfitIdea(
            onSave: _onSaveLook,
            onRegenerate: _handleGenerateLook,
            imageUrl: tryOnResultUrl ?? _todayLookImageUrl,
            isLoading: _loadingOutfits || isOutfitLoading,
            onGenerate: _handleGenerateLook,
            jobStatus: isOutfitLoading ? (tryOnJobId == 0 ? 'Creating...' : 'Generating...') : null,
            errorMessage: tryOnErrorMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeSection() {
    if (_loadingOutfits) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    final selectedDateStr = DateFormat('EEEE, MMMM d').format(DateTime.now().add(Duration(days: _selectedDayIndex)));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Items for $selectedDateStr", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        if (_todayGarments.isEmpty)
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(child: Text("No items planned for this day", style: TextStyle(color: AppColors.textSecondary))),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _todayGarments.length,
              itemBuilder: (context, index) {
                final garment = _todayGarments[index];
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: garment.imageUrl != null && garment.imageUrl!.isNotEmpty
                        ? Image.network(garment.imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildWeeklyWeatherBar() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isToday = index == 0;
          final isSelected = index == _selectedDayIndex;
          final weatherCode = _weeklyWeatherCodes.isNotEmpty ? _weeklyWeatherCodes[index] : 0;
          final highTemp = _weeklyHighTemps[index].round();
          final lowTemp = _weeklyLowTemps[index].round();

          return GestureDetector(
            onTap: () async {
              setState(() {
                _selectedDayIndex = index;
              });
              await _loadDailyData();
            },
            onLongPress: _showPlanSettings,
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primary.withOpacity(0.1) 
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border, 
                    width: isSelected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isToday ? "Today" : DateFormat('E').format(date),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Icon(_mapWeatherIcon(_mapWeatherCode(weatherCode)), size: 28, color: AppColors.textPrimary),
                  const SizedBox(height: 8),
                  Text("$highTemp° / $lowTemp°", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 輔助方法 ---

  String _mapWeatherCode(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Clouds';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    return 'Clouds';
  }

  Future<void> _createWeeklyPlan() async {
    if (_weeklyHighTemps.isEmpty) return;
    try {
      final adjustedTemps = _weeklyHighTemps.map((t) => t + _counterValue).toList();
      await WeeklyPlansService().createWeeklyPlan(tempsC: adjustedTemps, occasions: _weeklyOccasions);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugPrint('Failed to _createWeeklyPlan: $e');
    }
  }

  Future<void> _getGarments({int daysFromNow = 0}) async {
    final day = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: daysFromNow)));
    setState(() => _loadingOutfits = true);
    try {
      final list = await WeeklyPlansService().getGarments(day);
      List<Garment> fetchedGarments = List.from(list);
      //debugPrint('Fetched garments: ${fetchedGarments.map((g) => '{id: ${g.id}, imageUrl: ${g.imageUrl}}').toList()}');

      if (mounted) {
        setState(() {
          _todayGarments = fetchedGarments;
          _loadingOutfits = false;
        });
      }
    } on AuthExpiredException {
      if (mounted) {
        setState(() => _loadingOutfits = false);
        await AuthExpiredHandler.handle(context);
      }
    } catch (e) {
      debugPrint('Failed to _getGarments: $e');
      if (mounted) setState(() => _loadingOutfits = false);
    }
  }

  Future<void> _getOutfits({int daysFromNow = 0}) async {
    final day = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: daysFromNow)));
    try {
      final jobId = await WeeklyPlansService().getLook(day);
      if (jobId != null) {
        debugPrint('Fetched daily look jobId: $jobId');
        final statusRes = await OutfitService().getOutfit(jobId);
        final lookUrl = statusRes['result_image_url'];

        if (mounted) {
          setState(() {
            _todayLookImageUrl = lookUrl;
            resetTryOnState(); // Reset mixin state when switching days
          });
        }
      } else {
        if (mounted) setState(() => _todayLookImageUrl = null);
      }
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugPrint('Failed to _getOutfits: $e');
      if (mounted) setState(() => _todayLookImageUrl = null);
    }
  }

  Future<void> _handleGenerateLook() async {
    if (_todayGarments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No garments to generate look from.')));
      return;
    }

    final ids = _todayGarments.where((g) => g.id != null).map((g) => g.id!).toList();
    final int? jobId = await performTryOn(ids, "weekly");

    if (jobId != null) {
      debugPrint('_handleGenerateLook - jobId: $jobId');
      final day = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: _selectedDayIndex)));
      try {
        await WeeklyPlansService().saveJobId(day, jobId);
      } catch (e) {
        debugPrint('Failed to save jobId to weekly plan: $e');
      }
    }
  }

  Future<void> _onSaveLook() async {
    final url = tryOnResultUrl ?? _todayLookImageUrl;
    if (url == null) return;

    try {
      Look look = Look(
        id: tryOnJobId,
        imageUrl: url,
        seasons: _weeklyOccasions[_selectedDayIndex],
        style: 'Daily',
        advice: tryOnAiAdvice,
      );

      LooksStore.I.add(look);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Closet ✅')));
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }
    if (permission == LocationPermission.deniedForever) return Future.error('Location permissions are permanently denied');

    Position? lastPosition = await Geolocator.getLastKnownPosition();
    if (lastPosition != null) {
      return lastPosition;
    } else {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchWeather(double lat, double lon) async {
    final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=weathercode,temperature_2m_max,temperature_2m_min&current_weather=true&timezone=auto';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load weather');
  }

  Future<String> _getLocationName(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.administrativeArea ?? 'Unknown Location'}";
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return 'Unknown Location';
  }

  IconData _mapWeatherIcon(String condition) {
    switch (condition) {
      case 'Clear': return Icons.wb_sunny_rounded;
      case 'Clouds': return Icons.wb_cloudy_rounded;
      case 'Rain': return Icons.umbrella_rounded;
      case 'Snow': return Icons.ac_unit_rounded;
      default: return Icons.wb_cloudy_rounded;
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
  final double lat;
  final double lon;
  final List<int>? weeklyWeatherCodes;
  final List<double>? weeklyMaxTemps;
  final List<double>? weeklyMinTemps;

  CachedWeather({
    required this.location,
    required this.temp,
    required this.high,
    required this.low,
    required this.condition,
    required this.timestamp,
    required this.lat,
    required this.lon,
    this.weeklyWeatherCodes,
    this.weeklyMaxTemps,
    this.weeklyMinTemps,
  });

  factory CachedWeather.fromJson(Map<String, dynamic> json) => CachedWeather(
    location: json['location'],
    temp: (json['temp'] as num).toDouble(),
    high: json['high'],
    low: json['low'],
    condition: json['condition'],
    timestamp: json['timestamp'],
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    weeklyWeatherCodes: json['weeklyWeatherCodes'] != null ? List<int>.from(json['weeklyWeatherCodes']) : null,
    weeklyMaxTemps: json['weeklyMaxTemps'] != null ? List<double>.from(json['weeklyMaxTemps']) : null,
    weeklyMinTemps: json['weeklyMinTemps'] != null ? List<double>.from(json['weeklyMinTemps']) : null,
  );

  Map<String, dynamic> toJson() => {
    'location': location,
    'temp': temp,
    'high': high,
    'low': low,
    'condition': condition,
    'timestamp': timestamp,
    'lat': lat,
    'lon': lon,
    'weeklyWeatherCodes': weeklyWeatherCodes,
    'weeklyMaxTemps': weeklyMaxTemps,
    'weeklyMinTemps': weeklyMinTemps,
  };
}

class _TodayOutfitIdea extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onRegenerate;
  final String? imageUrl;
  final bool isLoading;
  final VoidCallback onGenerate;
  final String? jobStatus;
  final String? errorMessage;

  const _TodayOutfitIdea({
    required this.onSave,
    required this.onRegenerate,
    this.imageUrl,
    this.isLoading = false,
    required this.onGenerate,
    this.jobStatus,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: _buildLoadingView(),
            )
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: _buildErrorView(),
            )
          else if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: _buildPlaceholder(),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: _buildGenerateView(),
            ),
          
          if (hasImage && !isLoading && errorMessage == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text("Regenerate"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                      label: const Text("Save"),
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
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(jobStatus ?? "Loading...", style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: onGenerate, child: const Text("Try Again")),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
        const SizedBox(height: 16),
        const Text("Generating your look...", style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildGenerateView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome, size: 64, color: AppColors.primary.withOpacity(0.5)),
        const SizedBox(height: 16),
        const Text("No look image yet", style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.brush_rounded, size: 20, color: Colors.white,),
          label: const Text("Generate Look", style: TextStyle(color: Colors.white),),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
