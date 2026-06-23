import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/weekly_plans_service.dart';
import '../core/services/outfit_service.dart';
import 'try_on_mixin.dart';
import '../data/garment.dart';
import '../data/look.dart';
import '../core/providers/weather_provider.dart';
import '../data/trip_plan.dart';
import 'widgets/today_outfit_idea.dart';
import 'widgets/page_app_bar.dart';

class TripDetailsPage extends ConsumerStatefulWidget {
  final TripPlan trip;
  const TripDetailsPage({super.key, required this.trip});

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage>
    with TryOnMixin {
  bool _loading = true;
  int _selectedDayIndex = 0;

  List<int> _weatherCodes = [];
  List<double> _highTemps = [];
  List<double> _lowTemps = [];

  List<Garment> _todayGarments = [];
  bool _loadingOutfits = false;
  String? _todayLookImageUrl;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      await _fetchTripWeather();
      await _loadDailyData();
    } catch (e) {
      debugPrint('Trip initialization error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchTripWeather() async {
    final startOffset =
        widget.trip.dateRange.start.difference(DateTime.now()).inDays;
    final duration = widget.trip.dateRange.duration.inDays + 1;
    final lat = widget.trip.location.latitude;
    final lon = widget.trip.location.longitude;
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
        setState(() {
          _weatherCodes = List<int>.from(data['daily']['weathercode']);
          _highTemps = List<double>.from(data['daily']['temperature_2m_max']
              .map((t) => (t as num).toDouble()));
          _lowTemps = List<double>.from(data['daily']['temperature_2m_min']
              .map((t) => (t as num).toDouble()));
        });
      }
    } catch (e) {
      debugPrint('Fetch trip weather failed: $e');
    }
  }

  Future<void> _loadDailyData() async {
    await _getGarments();
    await _getOutfits();
  }

  Future<void> _getGarments() async {
    final date =
        widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex));
    final dayStr = DateFormat('yyyy-MM-dd').format(date);
    setState(() => _loadingOutfits = true);
    try {
      final list = await WeeklyPlansService().getGarments(dayStr);
      if (mounted) setState(() => _todayGarments = list);
    } catch (e) {
      debugPrint('Failed to get trip garments: $e');
    } finally {
      if (mounted) setState(() => _loadingOutfits = false);
    }
  }

  Future<void> _getOutfits() async {
    final date =
        widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex));
    final dayStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final jobId = await WeeklyPlansService().getLook(dayStr);
      if (jobId != null) {
        final statusRes = await OutfitService().getOutfit(jobId);
        if (mounted)
          setState(() => _todayLookImageUrl = statusRes['result_image_url']);
      } else {
        if (mounted) setState(() => _todayLookImageUrl = null);
      }
    } catch (e) {
      debugPrint('Failed to get trip outfits: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(widget.trip.location.name,
                  style: AppTextStyle.bold16),
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
          final date =
              widget.trip.dateRange.start.add(Duration(days: index));
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
                    width: isSelected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('M/d').format(date),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  if (_weatherCodes.length > index)
                    Column(
                      children: [
                        Icon(WeatherData.iconFromCondition(WeatherData.conditionFromCode(_weatherCodes[index])),
                            size: 28, color: AppColors.textPrimary),
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
        widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Wardrobe for $dateStr",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            : const Icon(Icons.inventory_2_outlined,
                color: AppColors.textSecondary),
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
          border: Border.all(color: AppColors.border)),
      child: Center(
          child: Text(msg,
              style: const TextStyle(color: AppColors.textSecondary))),
    );
  }

  Future<void> _handleGenerateLook() async {
    if (_todayGarments.isEmpty) return;
    final ids =
        _todayGarments.where((g) => g.id != null).map((g) => g.id!).toList();
    final int? jobId = await performTryOn(ids, "weekly");

    if (jobId != null) {
      final date =
          widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex));
      final dayStr = DateFormat('yyyy-MM-dd').format(date);
      try {
        await WeeklyPlansService().saveJobId(dayStr, jobId);
      } catch (e) {
        debugPrint('Failed to save jobId: $e');
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
        seasons: 'Trip',
        style: 'Daily',
        advice: tryOnAiAdvice,
      );
      ref.read(looksProvider.notifier).add(look);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved to Closet ✅')));
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }
}
