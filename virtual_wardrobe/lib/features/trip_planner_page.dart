import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/providers/trips_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/trip_plan_service.dart';
import '../core/utils/debug_log.dart';
import '../data/trip_plan.dart';
import 'trip_details_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/floating_nav_bar.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/trip/trip_plan_card.dart';
import 'widgets/trip/trip_plan_create_dialog.dart';

class TripPlannerPage extends ConsumerStatefulWidget {
  const TripPlannerPage({super.key});

  @override
  ConsumerState<TripPlannerPage> createState() => _TripPlannerPageState();
}

final _dateFmt = DateFormat('yyyy-MM-dd');

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Fetches per-day mean temperature for a leg, keyed by "yyyy-MM-dd".
/// Legs within Open-Meteo's ~16-day forecast horizon use live forecast
/// data; legs further out (forecasts don't exist that far ahead) fall
/// back to last year's actual weather for the same calendar dates as an
/// estimate.
Future<Map<String, double>> _fetchLegDailyTemps(TripLeg leg) async {
  final today = _dateOnly(DateTime.now());
  final startOffset = _dateOnly(leg.dateRange.start).difference(today).inDays;
  if (startOffset > 15) {
    return _fetchHistoricalLegTemps(leg);
  }
  return _fetchForecastLegTemps(leg);
}

Future<Map<String, double>> _fetchForecastLegTemps(TripLeg leg) async {
  final today = _dateOnly(DateTime.now());
  final startOffset = _dateOnly(leg.dateRange.start).difference(today).inDays;
  final duration = leg.dateRange.duration.inDays + 1;
  final lat = leg.location.latitude;
  final lon = leg.location.longitude;
  int daysNeeded = startOffset + duration;
  if (daysNeeded > 16) daysNeeded = 16;
  if (daysNeeded < 7) daysNeeded = 7;
  final url =
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&daily=temperature_2m_mean&timezone=auto&forecast_days=$daysNeeded';
  return _fetchDailyMap(url);
}

/// Beyond the forecast horizon there's no real forecast to fetch, so this
/// pulls last year's actual weather for the same calendar dates from
/// Open-Meteo's historical archive and shifts those dates forward a year
/// to key them onto this trip's real dates.
Future<Map<String, double>> _fetchHistoricalLegTemps(TripLeg leg) async {
  final start = leg.dateRange.start;
  final end = leg.dateRange.end;
  final histStart = DateTime(start.year - 1, start.month, start.day);
  final histEnd = DateTime(end.year - 1, end.month, end.day);
  final lat = leg.location.latitude;
  final lon = leg.location.longitude;
  final url =
      'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon'
      '&start_date=${_dateFmt.format(histStart)}&end_date=${_dateFmt.format(histEnd)}'
      '&daily=temperature_2m_mean&timezone=auto';

  final histTemps = await _fetchDailyMap(url);
  final shifted = <String, double>{};
  histTemps.forEach((dateStr, temp) {
    final d = DateTime.parse(dateStr);
    shifted[_dateFmt.format(DateTime(d.year + 1, d.month, d.day))] = temp;
  });
  return shifted;
}

/// Calls an Open-Meteo daily-temperature endpoint and maps its own
/// returned dates to values, rather than assuming a fixed offset from
/// "today" — the response's date range doesn't always start exactly where
/// requested.
Future<Map<String, double>> _fetchDailyMap(String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final times = List<String>.from(data['daily']['time']);
      final temps = List<double>.from(
        data['daily']['temperature_2m_mean'].map((t) => (t as num).toDouble()),
      );
      return {for (int i = 0; i < times.length; i++) times[i]: temps[i]};
    }
    debugLog(
      'Fetch daily temps failed: HTTP ${res.statusCode} for $url\n${res.body}',
    );
  } catch (e) {
    debugLog('Fetch daily temps failed: $e (url: $url)');
  }
  return const {};
}

/// Builds one `{date, temperature_c}` entry per day of the whole trip by
/// looking up, for each day, which leg covers it and pulling that leg's
/// mean temperature for that specific date.
Future<List<Map<String, dynamic>>> _fetchDailyTemperatures(
  TripPlan trip,
) async {
  final legTemps = <Map<String, double>>[];
  for (final leg in trip.legs) {
    legTemps.add(await _fetchLegDailyTemps(leg));
  }

  final totalDays = trip.dateRange.duration.inDays + 1;

  // Only include dates actually covered by a leg — the backend rejects
  // `days` entries for gap dates between legs.
  final days = <Map<String, dynamic>>[];
  for (int i = 0; i < totalDays; i++) {
    final date = trip.dateRange.start.add(Duration(days: i));
    final leg = trip.legForDate(date);
    if (leg == null) continue;

    final dateStr = _dateFmt.format(date);
    final legIndex = trip.legs.indexOf(leg);
    final temp = legTemps[legIndex][dateStr] ?? 0.0;

    days.add({'date': dateStr, 'temperature_c': temp.round()});
  }
  return days;
}

/// Shows the "New Trip" creation flow (location/date form, then weather
/// prefetch + create call) and adds the result to [tripsProvider]. Shared
/// between [TripPlannerPage]'s own "+" and any other entry point (e.g. the
/// Home page's quick-actions menu).
Future<void> handleCreateTrip(BuildContext context, WidgetRef ref) async {
  final input = await showDialog<TripPlan>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const TripPlanCreateDialog(),
  );
  if (input == null || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (_) => const LoadingOverlay(label: 'Creating Trip...'),
  );

  try {
    final days = await _fetchDailyTemperatures(input);
    debugLog('createTrip days: $days');
    final id = await TripPlanService().createTripPlan(
      name: input.name,
      legs: input.legs,
      purpose: input.purpose,
      days: days,
    );

    final newTrip = TripPlan(
      id: id.toString(),
      name: input.name,
      legs: input.legs,
      purpose: input.purpose,
    );
    ref.read(tripsProvider.notifier).add(newTrip);

    final initialData = await TripDetailsPage.preload(newTrip);

    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    // Jump the shell to the Trip Planner tab so that popping back off of
    // Trip Details always lands there, regardless of where trip creation
    // was started from (e.g. Home's quick-actions menu).
    MainShellScope.of(context)?.selectTab(AppTab.tripPlanner);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TripDetailsPage(trip: newTrip, initialData: initialData),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    if (e is AuthExpiredException) {
      await AuthExpiredHandler.handle(context);
      return;
    }
    debugLog('Failed to create trip: $e');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Failed to create trip')));
  }
}

class _TripPlannerPageState extends ConsumerState<TripPlannerPage> {
  bool _openingTrip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(tripsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);

    return Stack(
      children: [
        _buildScaffold(context, tripsAsync),
        if (_openingTrip)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Trip...'),
          ),
      ],
    );
  }

  AppToolBar _buildAppBar(BuildContext context) {
    return AppToolBar(
      title: 'Trip Planner',
      showBackButton: false,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/images/plus.png',
            height: AppDimens.iconMediumSize,
          ),
        ),
        onPressed: () => handleCreateTrip(context, ref),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<List<TripPlan>> tripsAsync,
  ) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateWidget(
            error: e,
            onRetry: () => ref.read(tripsProvider.notifier).refresh(),
          ),
          data: (trips) => RefreshIndicator(
            onRefresh: () => ref.read(tripsProvider.notifier).refresh(),
            child: trips.isEmpty
                ? ListView(
                    children: [
                      EmptyStatePlaceholder(
                        message: 'No trips planned yet',
                        icon: Icons.beach_access,
                        height: MediaQuery.of(context).size.height * 0.6,
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TripPlanCard(
                          key: ValueKey(trip.id),
                          trip: trip,
                          onTap: () => _handleOpenTrip(context, trip),
                          onNameChanged: (name) => _handleUpdateTrip(
                            context,
                            ref,
                            trip,
                            updated: trip.copyWith(name: name),
                          ),
                          onLegsChanged: (legs) => _handleUpdateTrip(
                            context,
                            ref,
                            trip,
                            updated: trip.copyWith(legs: legs),
                          ),
                          onPurposeChanged: (purpose) => _handleUpdateTrip(
                            context,
                            ref,
                            trip,
                            updated: trip.copyWith(purpose: purpose),
                          ),
                          onDelete: () => _handleDeleteTrip(context, ref, trip),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdateTrip(
    BuildContext context,
    WidgetRef ref,
    TripPlan trip, {
    required TripPlan updated,
  }) async {
    try {
      await TripPlanService().updateTripPlan(
        int.parse(trip.id),
        name: updated.name != trip.name ? updated.name : null,
        legs: updated.legs,
        purpose: updated.purpose != trip.purpose ? updated.purpose : null,
      );

      if (!context.mounted) return;
      ref.read(tripsProvider.notifier).updateTrip(updated);
    } catch (e) {
      if (!context.mounted) return;
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to update trip: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update trip')));
    }
  }

  Future<void> _handleDeleteTrip(
    BuildContext context,
    WidgetRef ref,
    TripPlan trip,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await TripPlanService().deleteTripPlan(int.parse(trip.id));

      if (!context.mounted) return;
      Navigator.pop(context); // close loading indicator
      ref.read(tripsProvider.notifier).remove(trip.id);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loading indicator
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to delete trip: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete trip')));
    }
  }

  Future<void> _handleOpenTrip(BuildContext context, TripPlan trip) async {
    setState(() => _openingTrip = true);
    try {
      final data = await TripDetailsPage.preload(trip);

      if (!mounted) return;
      setState(() => _openingTrip = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDetailsPage(trip: trip, initialData: data),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingTrip = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load trip details: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load trip details')),
        );
      }
    }
  }
}
