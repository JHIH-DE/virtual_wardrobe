import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/providers/trips_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/trip_service.dart';
import '../core/utils/debug_log.dart';
import '../data/trip.dart';
import '../l10n/generated/app_localizations.dart';
import 'trip_details_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/overlays/empty_state_placeholder.dart';
import 'widgets/common/overlays/error_state_widget.dart';
import 'widgets/common/floating_nav_bar.dart';
import 'widgets/common/labeled_divider.dart';
import 'widgets/common/overlays/loading_overlay.dart';
import 'widgets/trip/trip_card.dart';
import 'widgets/trip/trip_create_dialog.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripMainPageState();
}

final _dateFmt = DateFormat('yyyy-MM-dd');

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

enum _TripStatus { ongoing, upcoming, past }

_TripStatus _tripStatus(Trip trip, DateTime today) {
  final start = _dateOnly(trip.dateRange.start);
  final end = _dateOnly(trip.dateRange.end);
  if (today.isBefore(start)) return _TripStatus.upcoming;
  if (today.isAfter(end)) return _TripStatus.past;
  return _TripStatus.ongoing;
}

/// Fetches per-day mean temperature for a leg, keyed by "yyyy-MM-dd".
/// Legs within Open-Meteo's ~16-day forecast horizon use live forecast
/// data; legs further out (forecasts don't exist that far ahead) fall
/// back to last year's actual weather for the same calendar dates as an
/// estimate.
Future<Map<String, _DailyTemp>> _fetchLegDailyTemps(TripLeg leg) async {
  final today = _dateOnly(DateTime.now());
  final startOffset = _dateOnly(leg.dateRange.start).difference(today).inDays;
  if (startOffset > 15) {
    return _fetchHistoricalLegTemps(leg);
  }
  return _fetchForecastLegTemps(leg);
}

Future<Map<String, _DailyTemp>> _fetchForecastLegTemps(TripLeg leg) async {
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
      '&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=$daysNeeded';
  return _fetchDailyMap(url);
}

/// Beyond the forecast horizon there's no real forecast to fetch, so this
/// pulls last year's actual weather for the same calendar dates from
/// Open-Meteo's historical archive and shifts those dates forward a year
/// to key them onto this trip's real dates.
Future<Map<String, _DailyTemp>> _fetchHistoricalLegTemps(TripLeg leg) async {
  final start = leg.dateRange.start;
  final end = leg.dateRange.end;
  final histStart = DateTime(start.year - 1, start.month, start.day);
  final histEnd = DateTime(end.year - 1, end.month, end.day);
  final lat = leg.location.latitude;
  final lon = leg.location.longitude;
  final url =
      'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon'
      '&start_date=${_dateFmt.format(histStart)}&end_date=${_dateFmt.format(histEnd)}'
      '&daily=temperature_2m_max,temperature_2m_min&timezone=auto';

  final histTemps = await _fetchDailyMap(url);
  final shifted = <String, _DailyTemp>{};
  histTemps.forEach((dateStr, temp) {
    final d = DateTime.parse(dateStr);
    shifted[_dateFmt.format(DateTime(d.year + 1, d.month, d.day))] = temp;
  });
  return shifted;
}

/// One day's high/low, as the trip_plans API now wants them
/// (`temperature_max_c`/`temperature_min_c`) rather than a single mean.
class _DailyTemp {
  final double max;
  final double min;
  const _DailyTemp(this.max, this.min);
}

/// Calls an Open-Meteo daily-temperature endpoint and maps its own
/// returned dates to values, rather than assuming a fixed offset from
/// "today" — the response's date range doesn't always start exactly where
/// requested.
Future<Map<String, _DailyTemp>> _fetchDailyMap(String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final times = List<String>.from(data['daily']['time']);
      final maxTemps = List<double>.from(
        data['daily']['temperature_2m_max'].map((t) => (t as num).toDouble()),
      );
      final minTemps = List<double>.from(
        data['daily']['temperature_2m_min'].map((t) => (t as num).toDouble()),
      );
      return {
        for (int i = 0; i < times.length; i++)
          times[i]: _DailyTemp(maxTemps[i], minTemps[i]),
      };
    }
    debugLog(
      'Fetch daily temps failed: HTTP ${res.statusCode} for $url\n${res.body}',
    );
  } catch (e) {
    debugLog('Fetch daily temps failed: $e (url: $url)');
  }
  return const {};
}

/// Builds one `{date, temperature_max_c, temperature_min_c}` entry per day
/// of the whole trip by looking up, for each day, which leg covers it and
/// pulling that leg's high/low for that specific date.
Future<List<Map<String, dynamic>>> _fetchDailyTemperatures(Trip trip) async {
  final legTemps = <Map<String, _DailyTemp>>[];
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
    final temp = legTemps[legIndex][dateStr];

    days.add({
      'date': dateStr,
      'temperature_max_c': (temp?.max ?? 0.0).round(),
      'temperature_min_c': (temp?.min ?? 0.0).round(),
    });
  }
  return days;
}

/// Shows the "New Trip" creation flow (location/date form, then weather
/// prefetch + create call) and adds the result to [tripsProvider]. Shared
/// between [TripsPage]'s own "+" and any other entry point (e.g. the
/// Home page's quick-actions menu).
Future<void> handleCreateTrip(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final input = await showDialog<Trip>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const TripCreateDialog(),
  );
  if (input == null || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (_) => LoadingOverlay(label: l10n.creatingTripEllipsis),
  );

  try {
    final newTrip = await _createTrip(input);
    ref.read(tripsProvider.notifier).add(newTrip);
    final initialData = await TripDetailsPage.preload(newTrip);

    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    _goToNewTripDetails(context, newTrip, initialData);
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
    ).showSnackBar(SnackBar(content: Text(l10n.failedToCreateTrip)));
  }
}

/// Fetches the per-day weather needed by the backend, then creates the trip
/// plan record and returns it as a [Trip].
Future<Trip> _createTrip(Trip input) async {
  final days = await _fetchDailyTemperatures(input);
  debugLog('createTrip days: $days');
  final id = await TripService().createTrip(
    name: input.name,
    legs: input.legs,
    purpose: input.purpose,
    days: days,
  );
  return Trip(
    id: id.toString(),
    name: input.name,
    legs: input.legs,
    purpose: input.purpose,
  );
}

/// Jumps the shell to the Trips tab so that popping back off of Trip
/// Details always lands there, regardless of where trip creation was
/// started from (e.g. Home's quick-actions menu), then pushes Trip Details.
void _goToNewTripDetails(
  BuildContext context,
  Trip trip,
  TripDetailsInitialData initialData,
) {
  MainShellScope.of(context)?.selectTab(AppTab.tripPlanner);
  final route = MaterialPageRoute(
    builder: (_) => TripDetailsPage(trip: trip, initialData: initialData),
  );
  Navigator.push(context, route);
}

class _TripMainPageState extends ConsumerState<TripsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportLoadingState(ref.read(tripsProvider));
      ref.listenManual(tripsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
        _reportLoadingState(next);
      });
    });
  }

  /// Mirrors tripsProvider's loading state up to MainShell, which shows a
  /// full-screen overlay above the floating nav bar — see
  /// MainShellScope.setLoading for why this can't just be built inline.
  void _reportLoadingState(AsyncValue<List<Trip>> state) {
    MainShellScope.of(context)?.setLoading(
      state.isLoading,
      label: AppLocalizations.of(context).loadingTripsEllipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);
    return _buildScaffold(context, tripsAsync);
  }

  AppToolBar _buildAppBar(BuildContext context) {
    return AppToolBar(
      title: AppLocalizations.of(context).navTrips,
      showBackButton: false,
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<List<Trip>> tripsAsync,
  ) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(context),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          error: e,
          onRetry: () => ref.read(tripsProvider.notifier).refresh(),
        ),
        data: (trips) => _buildTripList(context, trips),
      ),
    );
  }

  Widget _buildTripList(BuildContext context, List<Trip> trips) {
    return RefreshIndicator(
      onRefresh: () => ref.read(tripsProvider.notifier).refresh(),
      child: trips.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                AppDimens.floatingNavBarClearance,
              ),
              children: _buildGroupedTripItems(context, trips),
            ),
    );
  }

  /// Splits [trips] into Ongoing / Upcoming / Past sections (each ordered
  /// by how soon they happen — Ongoing/Upcoming ascending by start date,
  /// Past descending so the most recently finished trip shows first), and
  /// interleaves a [LabeledDivider] header before each non-empty section.
  List<Widget> _buildGroupedTripItems(BuildContext context, List<Trip> trips) {
    final l10n = AppLocalizations.of(context);
    final today = _dateOnly(DateTime.now());

    final ongoing = <Trip>[];
    final upcoming = <Trip>[];
    final past = <Trip>[];
    for (final trip in trips) {
      switch (_tripStatus(trip, today)) {
        case _TripStatus.ongoing:
          ongoing.add(trip);
        case _TripStatus.upcoming:
          upcoming.add(trip);
        case _TripStatus.past:
          past.add(trip);
      }
    }
    ongoing.sort((a, b) => a.dateRange.start.compareTo(b.dateRange.start));
    upcoming.sort((a, b) => a.dateRange.start.compareTo(b.dateRange.start));
    past.sort((a, b) => b.dateRange.end.compareTo(a.dateRange.end));

    final items = <Widget>[];
    void addSection(String label, List<Trip> group, Color dotColor) {
      if (group.isEmpty) return;
      if (items.isNotEmpty) items.add(const SizedBox(height: 8));
      items.add(LabeledDivider(label: label, dotColor: dotColor));
      items.add(const SizedBox(height: 16));
      for (final trip in group) {
        items.add(_buildTripCard(context, trip));
      }
    }

    addSection(l10n.statusOngoing, ongoing, AppColors.statusOngoing);
    addSection(l10n.statusUpcoming, upcoming, AppColors.statusUpcoming);
    addSection(l10n.statusPast, past, AppColors.statusPast);

    return items;
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      children: [
        EmptyStatePlaceholder(
          message: AppLocalizations.of(context).noTripsPlannedYet,
          icon: Icons.beach_access,
          height: MediaQuery.of(context).size.height * 0.6,
        ),
      ],
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TripCard(
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
  }

  Future<void> _handleUpdateTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip, {
    required Trip updated,
  }) async {
    try {
      await TripService().updateTrip(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToUpdateTrip),
        ),
      );
    }
  }

  Future<void> _handleDeleteTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await TripService().deleteTrip(int.parse(trip.id));

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToDeleteTrip),
        ),
      );
    }
  }

  Future<void> _handleOpenTrip(BuildContext context, Trip trip) async {
    final l10n = AppLocalizations.of(context);
    MainShellScope.of(
      context,
    )?.setLoading(true, label: l10n.loadingTripEllipsis);
    try {
      final data = await TripDetailsPage.preload(trip);

      if (!mounted || !context.mounted) return;
      MainShellScope.of(context)?.setLoading(false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDetailsPage(trip: trip, initialData: data),
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      MainShellScope.of(context)?.setLoading(false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load trip details: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToLoadTripDetails),
          ),
        );
      }
    }
  }
}
