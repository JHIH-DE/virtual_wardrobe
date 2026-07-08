import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/providers/weather_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/look_service.dart';
import '../core/services/daily_looks_service.dart';
import '../core/services/trip_plan_service.dart';
import '../core/utils/debug_log.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/garment.dart';
import '../data/look.dart';
import '../data/trip_plan.dart';
import 'trip_suitcase_page.dart';
import 'widgets/app_text_field.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/page_app_bar.dart';
import 'widgets/today_outfit_idea.dart';

class TripDetailsInitialData {
  final List<int> weatherCodes;
  final List<double> highTemps;
  final List<double> lowTemps;
  final List<Garment> todayGarments;
  final String? todayLookImageUrl;

  const TripDetailsInitialData({
    required this.weatherCodes,
    required this.highTemps,
    required this.lowTemps,
    required this.todayGarments,
    required this.todayLookImageUrl,
  });
}

class _WeatherForecast {
  final List<int> codes;
  final List<double> highs;
  final List<double> lows;

  const _WeatherForecast({
    required this.codes,
    required this.highs,
    required this.lows,
  });
}

Future<_WeatherForecast> _fetchWeather(TripPlan trip) async {
  final startOffset = trip.dateRange.start.difference(DateTime.now()).inDays;
  final duration = trip.dateRange.duration.inDays + 1;
  final lat = trip.location.latitude;
  final lon = trip.location.longitude;
  int daysNeeded = startOffset + duration;
  if (daysNeeded > 16) daysNeeded = 16;
  if (daysNeeded < 7) daysNeeded = 7;
  final url =
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min'
      '&timezone=auto&forecast_days=$daysNeeded';

  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return _WeatherForecast(
        codes: List<int>.from(data['daily']['weathercode']),
        highs: List<double>.from(
          data['daily']['temperature_2m_max'].map(
            (t) => (t as num).toDouble(),
          ),
        ),
        lows: List<double>.from(
          data['daily']['temperature_2m_min'].map(
            (t) => (t as num).toDouble(),
          ),
        ),
      );
    }
  } catch (e) {
    debugLog('Fetch trip weather failed: $e');
  }
  return const _WeatherForecast(codes: [], highs: [], lows: []);
}

class TripDetailsPage extends ConsumerStatefulWidget {
  final TripPlan trip;
  final TripDetailsInitialData initialData;

  const TripDetailsPage({
    super.key,
    required this.trip,
    required this.initialData,
  });

  /// Fetches everything [TripDetailsPage] needs up front, so the page can be
  /// pushed only once loading is complete (no in-page spinner on open).
  static Future<TripDetailsInitialData> preload(TripPlan trip) async {
    final weather = await _fetchWeather(trip);
    final dayStr = DateFormat('yyyy-MM-dd').format(trip.dateRange.start);

    List<Garment> garments = [];
    try {
      garments = await DailyLookService().getGarments(dayStr);
    } catch (e) {
      if (e is AuthExpiredException) rethrow;
      debugLog('Failed to get trip garments: $e');
    }

    String? lookImageUrl;
    try {
      final jobId = await DailyLookService().getLook(dayStr);
      if (jobId != null) {
        final statusRes = await LookService().getLook(jobId);
        lookImageUrl = statusRes['result_image_url'];
      }
    } catch (e) {
      if (e is AuthExpiredException) rethrow;
      debugLog('Failed to get trip outfits: $e');
    }

    return TripDetailsInitialData(
      weatherCodes: weather.codes,
      highTemps: weather.highs,
      lowTemps: weather.lows,
      todayGarments: garments,
      todayLookImageUrl: lookImageUrl,
    );
  }

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage>
    with TryOnMixin {
  int _selectedDayIndex = 0;
  bool _savingTrip = false;

  late final TextEditingController _nameController = TextEditingController(
    text: widget.trip.name,
  );

  late final List<int> _weatherCodes = widget.initialData.weatherCodes;
  late final List<double> _highTemps = widget.initialData.highTemps;
  late final List<double> _lowTemps = widget.initialData.lowTemps;

  late List<Garment> _todayGarments = widget.initialData.todayGarments;
  bool _loadingOutfits = false;
  late String? _todayLookImageUrl = widget.initialData.todayLookImageUrl;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveTrip() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip name cannot be empty')));
      return;
    }

    setState(() => _savingTrip = true);
    try {
      await TripPlanService().updateTripPlan(
        int.parse(widget.trip.id),
        name: name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip saved')));
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to save trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save trip')));
      }
    } finally {
      if (mounted) setState(() => _savingTrip = false);
    }
  }

  Future<void> _loadDailyData() async {
    await _getGarments();
    await _getOutfits();
  }

  Future<void> _getGarments() async {
    final date = widget.trip.dateRange.start.add(
      Duration(days: _selectedDayIndex),
    );
    final dayStr = DateFormat('yyyy-MM-dd').format(date);
    setState(() => _loadingOutfits = true);
    try {
      final list = await DailyLookService().getGarments(dayStr);
      if (mounted) setState(() => _todayGarments = list);
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to get trip garments: $e');
    } finally {
      if (mounted) setState(() => _loadingOutfits = false);
    }
  }

  Future<void> _getOutfits() async {
    final date = widget.trip.dateRange.start.add(
      Duration(days: _selectedDayIndex),
    );
    final dayStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final jobId = await DailyLookService().getLook(dayStr);
      if (jobId != null) {
        final statusRes = await LookService().getLook(jobId);
        if (mounted) {
          setState(() => _todayLookImageUrl = statusRes['result_image_url']);
        }
      } else {
        if (mounted) setState(() => _todayLookImageUrl = null);
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to get trip outfits: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: const PageAppBar(
        title: 'Trip Details',
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(controller: _nameController, label: 'Trip Name'),
            const SizedBox(height: 20),
            _buildTripHeader(),
            const SizedBox(height: 20),
            _buildSuitcaseSection(),
            const SizedBox(height: 20),
            _buildTripDaySelector(),
            const SizedBox(height: 20),
            _buildWardrobeSection(),
            const SizedBox(height: 20),
            TodayOutfitIdea(
              onSave: _onSaveLook,
              onGenerate: _handleGenerateLook,
              imageUrl: tryOnResultUrl ?? _todayLookImageUrl,
              isLoading: _loadingOutfits || isOutfitLoading,
              jobStatus: isOutfitLoading
                  ? (tryOnJobId == 0 ? 'Creating...' : 'Generating...')
                  : null,
              errorMessage: tryOnErrorMessage,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionButton(
        label: 'Save Trip',
        onPressed: _handleSaveTrip,
        isLoading: _savingTrip,
        buttonColor: AppColors.primary,
        textColor: Colors.white,
      ),
    );
  }

  Widget _buildTripHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(widget.trip.location.name, style: AppTextStyle.bold16),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${DateFormat('MMM d').format(widget.trip.dateRange.start)} - "
            "${DateFormat('MMM d, yyyy').format(widget.trip.dateRange.end)}",
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDaySelector() {
    final int totalDays = widget.trip.dateRange.duration.inDays + 1;
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalDays,
        itemBuilder: (context, index) {
          final date = widget.trip.dateRange.start.add(Duration(days: index));
          final isSelected = index == _selectedDayIndex;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDayIndex = index);
              _loadDailyData();
            },
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
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('M/d').format(date),
                    style: AppTextStyle.regular16.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_weatherCodes.length > index)
                    Column(
                      children: [
                        Icon(
                          WeatherData.iconFromCondition(
                            WeatherData.conditionFromCode(_weatherCodes[index]),
                          ),
                          size: 28,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_highTemps[index].round()}° / ${_lowTemps[index].round()}°",
                          style: AppTextStyle.semibold14,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWardrobeSection() {
    final dateStr = DateFormat('EEEE, MMM d').format(
      widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Wardrobe for $dateStr",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_loadingOutfits)
          const Center(child: CircularProgressIndicator())
        else if (_todayGarments.isEmpty)
          _buildEmptyState("No items planned")
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _todayGarments.length,
              itemBuilder: (context, index) =>
                  _buildGarmentItem(_todayGarments[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildSuitcaseSection() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripSuitcasePage(trip: widget.trip),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.luggage_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suitcase', style: AppTextStyle.bold16),
                  Text(
                    'Pack clothing for this trip',
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGarmentItem(Garment g) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: g.imageUrl != null && g.imageUrl!.isNotEmpty
            ? Image.network(g.imageUrl!, fit: BoxFit.cover)
            : const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Future<void> _handleGenerateLook() async {
    if (_todayGarments.isEmpty) return;
    final ids = _todayGarments
        .where((g) => g.id != null)
        .map((g) => g.id!)
        .toList();
    final int? jobId = await performTryOn(ids, "weekly");

    if (jobId != null) {
      final date = widget.trip.dateRange.start.add(
        Duration(days: _selectedDayIndex),
      );
      final dayStr = DateFormat('yyyy-MM-dd').format(date);
      try {
        await DailyLookService().saveJobId(dayStr, jobId);
      } catch (e) {
        if (e is AuthExpiredException) {
          await AuthExpiredHandler.handle(context);
          return;
        }
        debugLog('Failed to save jobId: $e');
      }
    }
  }

  Future<void> _onSaveLook() async {
    final url = tryOnResultUrl ?? _todayLookImageUrl;
    if (url == null) return;

    try {
      final look = Look(
        id: tryOnJobId,
        imageUrl: url,
        seasons: const [],
        style: const [],
        advice: tryOnAiAdvice,
      );
      ref.read(looksProvider.notifier).add(look);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to Closet ✅')));
      }
    } catch (e) {
      debugLog('Save error: $e');
    }
  }
}
