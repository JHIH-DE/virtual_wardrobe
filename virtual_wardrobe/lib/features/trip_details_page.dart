import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../core/services/trip_plan_service.dart';
import '../core/utils/debug_log.dart';
import '../core/utils/signed_url.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/garment.dart';
import '../data/look.dart';
import '../data/trip_plan.dart';
import '../l10n/generated/app_localizations.dart';
import 'trip_suitcase_page.dart';
import 'widgets/common/app_list_card.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/lumi_insight_card.dart';
import 'widgets/trip/today_outfit_idea.dart';
import 'widgets/garment/garment_image.dart';
import 'widgets/trip/trip_day_card.dart';

/// One trip day's primary outfit option, as returned embedded in
/// `TripPlanService.getTripPlan`'s `days[].options[]` — no separate
/// per-day fetch needed once the trip has been loaded.
class TripDayOutfit {
  final int? optionId;
  final List<Garment> garments;
  final int? jobId;

  const TripDayOutfit({this.optionId, this.garments = const [], this.jobId});
}

class TripDetailsInitialData {
  final List<int> weatherCodes;
  final List<double> highTemps;
  final List<double> lowTemps;
  final List<TripDayOutfit> dayOutfits;

  const TripDetailsInitialData({
    required this.weatherCodes,
    required this.highTemps,
    required this.lowTemps,
    required this.dayOutfits,
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
      final daily = data['daily'];
      if (daily == null) {
        return const _WeatherForecast(codes: [], highs: [], lows: []);
      }

      // Robust parsing: handle nulls or missing values in API response
      return _WeatherForecast(
        codes:
            (daily['weathercode'] as List?)
                ?.map((v) => (v as num?)?.toInt() ?? 0)
                .toList() ??
            [],
        highs:
            (daily['temperature_2m_max'] as List?)
                ?.map((v) => (v as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [],
        lows:
            (daily['temperature_2m_min'] as List?)
                ?.map((v) => (v as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [],
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

/// Picks the primary (lowest `order_index`) outfit option for one trip day
/// and resolves its garment ids against [garmentsById].
TripDayOutfit _parseTripDayOutfit(
  Map<String, dynamic> day,
  Map<int, Garment> garmentsById,
) {
  final options =
      ((day['options'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort(
          (a, b) => ((a['order_index'] as num?) ?? 0).compareTo(
            (b['order_index'] as num?) ?? 0,
          ),
        );
  if (options.isEmpty) return const TripDayOutfit();

  final primary = options.first;
  final items = ((primary['items'] as List?) ?? [])
      .whereType<Map<String, dynamic>>();
  final garments = items
      .map((i) => garmentsById[(i['garment_id'] as num?)?.toInt()])
      .whereType<Garment>()
      .toList();

  return TripDayOutfit(
    optionId: (primary['id'] as num?)?.toInt(),
    garments: garments,
    jobId: (primary['job_id'] as num?)?.toInt(),
  );
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

    List<TripDayOutfit> dayOutfits = [];
    try {
      final tripData = await TripPlanService().getTripPlan(int.parse(trip.id));
      final allGarments = await GarmentService().getGarments();
      final garmentsById = {
        for (final g in allGarments)
          if (g.id != null) g.id!: g,
      };

      final rawDays = (tripData['days'] as List?) ?? [];
      dayOutfits = rawDays
          .whereType<Map<String, dynamic>>()
          .map((day) => _parseTripDayOutfit(day, garmentsById))
          .toList();
    } catch (e) {
      if (e is AuthExpiredException) rethrow;
      debugLog('Failed to load trip outfits: $e');
    }

    return TripDetailsInitialData(
      weatherCodes: weather.codes,
      highTemps: weather.highs,
      lowTemps: weather.lows,
      dayOutfits: dayOutfits,
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
  late List<TripDayOutfit> _dayOutfits = widget.initialData.dayOutfits;

  bool _loadingPackingAdvice = false;
  String? _packingAdvice;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  TripDayOutfit? get _currentDayOutfit => _selectedDayIndex < _dayOutfits.length
      ? _dayOutfits[_selectedDayIndex]
      : null;

  List<Garment> get _todayGarments => _currentDayOutfit?.garments ?? const [];

  @override
  void initState() {
    super.initState();
    _loadPackingAdvice();
    _loadOutfitImage();
    // preload() fetched fresh garment image URLs, but if this page instance
    // stays open long enough for them to expire (e.g. backgrounded, or the
    // trip was preloaded a while before the user actually opened it), there
    // was previously no way to recover — the day outfits were immutable.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureFreshDayGarments(),
    );
  }

  Future<void> _loadOutfitImage() async {
    final jobId = _currentDayOutfit?.jobId;
    if (jobId != null && jobId != 0) await watchJob(jobId);
  }

  bool get _hasStaleGarmentImages => _dayOutfits.any(
    (day) => day.garments.any((g) {
      final url = g.imageUrl;
      return url != null && url.isNotEmpty && isSignedUrlExpired(url);
    }),
  );

  Future<void> _ensureFreshDayGarments() async {
    if (!_hasStaleGarmentImages) return;
    try {
      final fresh = await GarmentService().getGarments();
      final freshById = {
        for (final g in fresh)
          if (g.id != null) g.id!: g,
      };
      if (!mounted) return;
      setState(() {
        _dayOutfits = _dayOutfits
            .map(
              (day) => TripDayOutfit(
                optionId: day.optionId,
                jobId: day.jobId,
                garments: day.garments
                    .map((g) => freshById[g.id] ?? g)
                    .toList(),
              ),
            )
            .toList();
      });
    } catch (_) {
      // Leave the existing URLs; GarmentImage's errorWidget covers the
      // fallback if they've truly expired.
    }
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
    resetTryOnState();
    await _loadOutfitImage();
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: widget.trip.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _paddedSection(_buildTripHeader()),
          const SizedBox(height: 20),
          _paddedSection(_buildLumiInsightCard()),
          const SizedBox(height: 20),
          _paddedSection(_buildSuitcaseSection()),
          const SizedBox(height: 20),
          _buildTripDaySelector(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _paddedSection(_buildWardrobeSection()),
                const SizedBox(height: 20),
                _paddedSection(_buildOutfitSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paddedSection(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  Widget _buildOutfitSection() {
    return TodayOutfitIdea(
      onSave: _onSaveLook,
      onGenerate: _handleGenerateLook,
      imageUrl: tryOnResultUrl,
      isLoading: isLookLoading,
      jobStatus: isLookLoading
          ? (tryOnJobId == 0 ? _l10n.creatingEllipsis : _l10n.generatingEllipsis)
          : null,
      errorMessage: tryOnErrorMessage,
    );
  }

  Widget _buildTripHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.trip.legs.length; i++) ...[
            if (i > 0) _buildLegDivider(),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.icon, size: 18),
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
      child: Divider(height: 1, thickness: 1, color: AppColors.dividerStrong),
    );
  }

  Widget _buildTripDaySelector() {
    final int totalDays = widget.trip.dateRange.duration.inDays + 1;
    return SizedBox(
      height: 102,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: totalDays,
        itemBuilder: (context, index) {
          final date = widget.trip.dateRange.start.add(Duration(days: index));
          final hasWeather = _weatherCodes.length > index;
          return TripDayCard(
            date: date,
            isSelected: index == _selectedDayIndex,
            onTap: () {
              setState(() => _selectedDayIndex = index);
              _loadDailyData();
            },
            weatherCode: hasWeather ? _weatherCodes[index] : null,
            lowTemp: hasWeather ? _lowTemps[index] : null,
            highTemp: hasWeather ? _highTemps[index] : null,
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
          _l10n.wardrobeForDate(dateStr),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_todayGarments.isEmpty)
          EmptyStatePlaceholder(
            message: _l10n.noItemsPlanned,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(16)),
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.borderSubtle),
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

  Widget _buildLumiInsightCard() {
    if (!_loadingPackingAdvice &&
        (_packingAdvice == null || _packingAdvice!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return LumiInsightCard(
      child: _loadingPackingAdvice
          ? Row(
              children: [
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  _l10n.thinkingEllipsis,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          : Text(
              _packingAdvice!,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
    );
  }

  Widget _buildSuitcaseSection() {
    return AppListCard(
      title: _l10n.suitcaseLabel,
      leading: const Icon(Icons.luggage_outlined, color: AppColors.icon),
      showArrow: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: widget.trip)),
      ),
      child: Text(
        _l10n.packClothingHint,
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
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: GarmentImage(url: g.imageUrl, fit: BoxFit.cover, borderRadius: 12),
    );
  }

  Future<void> _handleGenerateLook() async {
    if (_todayGarments.isEmpty) return;
    final optionId = _currentDayOutfit?.optionId;
    if (optionId == null) return;

    final ids = _todayGarments
        .where((g) => g.id != null)
        .map((g) => g.id!)
        .toList();
    final int? jobId = await performTryOn(ids, "weekly");

    if (jobId != null) {
      try {
        await TripPlanService().setTryonJobToOption(
          jobId,
          optionId: optionId,
          tripId: int.parse(widget.trip.id),
        );
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
    final url = tryOnResultUrl;
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
        ).showSnackBar(SnackBar(content: Text(_l10n.savedToCloset)));
      }
    } catch (e) {
      debugLog('Save error: $e');
    }
  }
}
