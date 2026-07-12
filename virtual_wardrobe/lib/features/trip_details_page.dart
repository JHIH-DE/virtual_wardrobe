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
import 'widgets/common/app_list_card.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/info_banner.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/common/today_outfit_idea.dart';
import 'widgets/garment/garment_image.dart';

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

/// Fetches the full (unsliced) forecast for a single leg, covering exactly
/// that leg's own date range.
Future<_WeatherForecast> _fetchLegWeather(TripLeg leg) async {
  final startOffset = leg.dateRange.start.difference(DateTime.now()).inDays;
  final duration = leg.dateRange.duration.inDays + 1;
  final lat = leg.location.latitude;
  final lon = leg.location.longitude;
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
          data['daily']['temperature_2m_max'].map((t) => (t as num).toDouble()),
        ),
        lows: List<double>.from(
          data['daily']['temperature_2m_min'].map((t) => (t as num).toDouble()),
        ),
      );
    }
  } catch (e) {
    debugLog('Fetch leg weather failed: $e');
  }
  return const _WeatherForecast(codes: [], highs: [], lows: []);
}

/// Builds one weather entry per day of the whole trip by looking up, for
/// each day, which leg covers it and pulling that leg's forecast for that
/// day. Robust to legs being entered out of chronological order.
Future<_WeatherForecast> _fetchWeather(TripPlan trip) async {
  final legForecasts = <_WeatherForecast>[];
  for (final leg in trip.legs) {
    legForecasts.add(await _fetchLegWeather(leg));
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final totalDays = trip.dateRange.duration.inDays + 1;
  final codes = <int>[];
  final highs = <double>[];
  final lows = <double>[];
  for (int i = 0; i < totalDays; i++) {
    final date = trip.dateRange.start.add(Duration(days: i));
    final leg = trip.legForDate(date);
    final legIndex = leg == null ? -1 : trip.legs.indexOf(leg);
    if (legIndex == -1) {
      // No leg covers this day (gap between legs); no data to show.
      codes.add(0);
      highs.add(0);
      lows.add(0);
      continue;
    }
    final forecast = legForecasts[legIndex];
    // Open-Meteo's response always starts at "today", regardless of which
    // leg it's for, so every leg's array is indexed the same way.
    final dayOffset = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(today).inDays;
    if (dayOffset >= 0 && dayOffset < forecast.codes.length) {
      codes.add(forecast.codes[dayOffset]);
      highs.add(forecast.highs[dayOffset]);
      lows.add(forecast.lows[dayOffset]);
    } else {
      codes.add(0);
      highs.add(0);
      lows.add(0);
    }
  }
  return _WeatherForecast(codes: codes, highs: highs, lows: lows);
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

  late final List<int> _weatherCodes = widget.initialData.weatherCodes;
  late final List<double> _highTemps = widget.initialData.highTemps;
  late final List<double> _lowTemps = widget.initialData.lowTemps;

  late List<Garment> _todayGarments = widget.initialData.todayGarments;
  bool _loadingOutfits = false;
  late String? _todayLookImageUrl = widget.initialData.todayLookImageUrl;

  bool _loadingPackingAdvice = false;
  String? _packingAdvice;

  @override
  void initState() {
    super.initState();
    _loadPackingAdvice();
  }

  Future<void> _loadPackingAdvice() async {
    setState(() => _loadingPackingAdvice = true);
    try {
      final data = await TripPlanService().getTripSuggestion(
        int.parse(widget.trip.id),
      );
      if (mounted) {
        setState(() => _packingAdvice = data['overall_advice'] as String?);
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to analyze trip plan: $e');
    } finally {
      if (mounted) setState(() => _loadingPackingAdvice = false);
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
      appBar: PageAppBar(
        title: widget.trip.name,
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTripHeader(),
            const SizedBox(height: 20),
            _buildPackingAdviceSection(),
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
          for (int i = 0; i < widget.trip.legs.length; i++) ...[
            if (i > 0) _buildLegDivider(),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.trip.legs[i].location.name,
                    style: AppTextStyle.bold16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${DateFormat('MMM d').format(widget.trip.legs[i].dateRange.start)} - "
                  "${DateFormat('MMM d').format(widget.trip.legs[i].dateRange.end)}",
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Divider(height: 1, thickness: 1, color: AppColors.defaultDivider),
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
          const EmptyStatePlaceholder(
            message: "No items planned",
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(16)),
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.border),
              ),
            ),
          )
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

  Widget _buildPackingAdviceSection() {
    if (!_loadingPackingAdvice &&
        (_packingAdvice == null || _packingAdvice!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return InfoBanner(
      iconSize: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LUMI', style: AppTextStyle.bold16),
          const SizedBox(height: 6),
          if (_loadingPackingAdvice)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              _packingAdvice!,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuitcaseSection() {
    return AppListCard(
      title: 'Suitcase',
      leading: const Icon(Icons.luggage_outlined, color: AppColors.primary),
      showArrow: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: widget.trip)),
      ),
      child: Text(
        'Pack clothing for this trip',
        style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
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
      child: GarmentImage(url: g.imageUrl, fit: BoxFit.cover, borderRadius: 12),
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
