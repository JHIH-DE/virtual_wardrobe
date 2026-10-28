import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/providers/trip_detail_provider.dart';
import '../../core/providers/trips_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/trip.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/main_nav_bar.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/main_tab_async.dart';
import '../widgets/common/overlays/ai_consent_dialog.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/trip/trip_card.dart';
import '../widgets/trip/trip_create_dialog.dart';
import 'trip_details_page.dart';
import 'trip_suitcase_page.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

enum _TripStatus { ongoing, upcoming, past }

_TripStatus _tripStatus(Trip trip, DateTime today) {
  final start = _dateOnly(trip.dateRange.start);
  final end = _dateOnly(trip.dateRange.end);
  if (today.isBefore(start)) return _TripStatus.upcoming;
  if (today.isAfter(end)) return _TripStatus.past;
  return _TripStatus.ongoing;
}

/// The "New Trip" flow: create dialog, create call, then opens the new
/// trip. Shared by Trips' empty state and the shell's quick actions.
Future<void> handleCreateTrip(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onCreated,
}) async {
  if (!await ensureAiConsent(context) || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  // Captured up front: `context` may be gone after the awaits, and the
  // loading overlay must be popped from the navigator showDialog used.
  final navigator = Navigator.of(context, rootNavigator: true);

  final input = await showDialog<Trip>(
    context: context,
    builder: (_) => const TripCreateDialog(),
  );
  if (input == null || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    builder: (_) => LoadingOverlay(label: l10n.creatingTripEllipsis),
  );

  try {
    final newTrip = await _createTrip(input);
    ref.read(tripsProvider.notifier).addTrip(newTrip);
    try {
      await _loadTripDetail(ref, newTrip);
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
      // The trip was created — open it anyway; the next visit retries.
      debugLog('Failed to load new trip detail: $e');
    }

    navigator.pop(); // close loading indicator
    onCreated?.call();
    // Trip Details goes under Suitcase so backing out of Suitcase lands
    // there; only the second push visibly animates.
    navigator.push(
      MaterialPageRoute(builder: (_) => TripDetailsPage(trip: newTrip)),
    );
    navigator.push(
      MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: newTrip)),
    );
  } on AuthExpiredException {
    navigator.pop(); // close loading indicator
    if (context.mounted) await AuthExpiredHandler.handle(context);
  } catch (e) {
    navigator.pop(); // close loading indicator
    debugLog('Failed to create trip: $e');
    if (context.mounted) {
      showErrorDialog(context, message: l10n.failedToCreateTrip);
    }
  }
}

/// Optimistic rename for a trip list card (Trips and Home).
Future<void> handleRenameTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  String name,
) async {
  final updated = trip.copyWith(name: name);
  ref.read(tripsProvider.notifier).updateTrip(updated);
  try {
    await TripService().updateTrip(int.parse(trip.id), name: name);
  } on AuthExpiredException {
    if (!context.mounted) return;
    ref.read(tripsProvider.notifier).updateTrip(trip);
    await AuthExpiredHandler.handle(context);
  } catch (e) {
    if (!context.mounted) return;
    ref.read(tripsProvider.notifier).updateTrip(trip);
    debugLog('Failed to rename trip: $e');
    showErrorDialog(
      context,
      message: AppLocalizations.of(context).failedToUpdateTrip,
    );
  }
}

/// Deletes a trip from a list card (Trips and Home).
Future<void> handleDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
) async {
  final l10n = AppLocalizations.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    builder: (_) => LoadingOverlay(label: l10n.deletingTripEllipsis),
  );

  try {
    await TripService().deleteTrip(int.parse(trip.id));

    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    ref.read(tripsProvider.notifier).removeTrip(trip.id);
  } on AuthExpiredException {
    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    await AuthExpiredHandler.handle(context);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    debugLog('Failed to delete trip: $e');
    showErrorDialog(
      context,
      message: AppLocalizations.of(context).failedToDeleteTrip,
    );
  }
}

/// Waits for [trip]'s [tripDetailProvider] to finish its first load (a
/// no-op once cached). A previous failed load is retried from scratch.
Future<void> _loadTripDetail(WidgetRef ref, Trip trip) async {
  final provider = tripDetailProvider(int.parse(trip.id));
  if (ref.read(provider).hasError) ref.invalidate(provider);
  // A real listener for the duration of the load, so appRetryPolicy's
  // scheduled retries actually run.
  final subscription = ref.listenManual(provider, (_, _) {});
  try {
    await ref.read(provider.future);
  } finally {
    subscription.close();
  }
}

/// Opens [TripDetailsPage]. Only the first visit this session shows [tab]'s
/// loading overlay; later visits open at once from [tripDetailProvider].
Future<void> openTripDetails(
  BuildContext context,
  WidgetRef ref,
  Trip trip, {
  required MainTab tab,
}) async {
  // Trip Details' load runs the AI packing analysis when none exists yet.
  if (!await ensureAiConsent(context) || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final cached = ref.read(tripDetailProvider(int.parse(trip.id)));
  final needsLoad = !cached.hasValue || cached.hasError;
  if (needsLoad) {
    MainShellScope.of(
      context,
    )?.setLoading(true, label: l10n.loadingTripEllipsis, tab: tab);
  }
  try {
    if (needsLoad) await _loadTripDetail(ref, trip);
    if (!context.mounted) return;
    MainShellScope.of(context)?.setLoading(false, tab: tab);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailsPage(trip: trip)),
    );
  } on AuthExpiredException {
    if (!context.mounted) return;
    MainShellScope.of(context)?.setLoading(false, tab: tab);
    await AuthExpiredHandler.handle(context);
  } catch (e) {
    if (!context.mounted) return;
    MainShellScope.of(context)?.setLoading(false, tab: tab);
    debugLog('Failed to load trip details: $e');
    showErrorDialog(context, message: l10n.failedToLoadTripDetails);
  }
}

/// Per-day temperatures aren't sent; the backend derives them from the legs.
Future<Trip> _createTrip(Trip input) async {
  final id = await TripService().createTrip(
    name: input.name,
    legs: input.legs,
    activities: input.activities,
  );
  return Trip(
    id: id.toString(),
    name: input.name,
    legs: input.legs,
    activities: input.activities,
  );
}

class _TripsPageState extends ConsumerState<TripsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final report = mainTabReporter(
        context,
        loadingLabel: AppLocalizations.of(context).loadingTripsEllipsis,
        tab: MainTab.tripPlanner,
      );
      report(ref.read(tripsProvider));
      ref.listenManual(tripsProvider, (_, next) => report(next));
    });
  }

  AppToolBar _buildAppBar(AsyncValue<List<Trip>> tripsAsync) {
    return AppToolBar(
      title: AppLocalizations.of(context).navTrips,
      titleCount: (tripsAsync.value ?? const []).length,
      centerTitle: false,
      showBackButton: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(tripsAsync),
      body: tripsAsync.mainTabBody(
        data: _buildTripList,
        onRetry: () => ref.read(tripsProvider.notifier).refresh(),
      ),
    );
  }

  Widget _buildTripList(List<Trip> trips) {
    return RefreshIndicator(
      onRefresh: () => ref.read(tripsProvider.notifier).refresh(),
      child: trips.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                AppDimens.mainNavBarClearance,
              ),
              children: _buildGroupedTripItems(trips),
            ),
    );
  }

  /// Ongoing / Upcoming (by start date) and Past (most recently ended first)
  /// sections, each under a [LabeledDivider].
  List<Widget> _buildGroupedTripItems(List<Trip> trips) {
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
      items.add(LabeledDivider(label: label, dotColor: dotColor));
      items.add(const SizedBox(height: AppDimens.cardHeaderGap));
      for (final trip in group) {
        items.add(_buildTripCard(trip));
      }
    }

    addSection(l10n.statusOngoing, ongoing, AppColors.statusOngoing);
    addSection(l10n.statusUpcoming, upcoming, AppColors.statusUpcoming);
    addSection(l10n.statusPast, past, AppColors.statusPast);

    return items;
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return EmptyStatePlaceholder(
      icon: Icons.beach_access,
      title: l10n.noTripsPlannedYet,
      message: l10n.tripsEmptyHint,
      actionLabel: l10n.newTrip,
      onAction: () => handleCreateTrip(context, ref),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      fillAvailableSpace: true,
      bottomInset: AppDimens.mainNavBarClearance,
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionSpacing),
      child: TripCard(
        key: ValueKey(trip.id),
        trip: trip,
        onTap: () =>
            openTripDetails(context, ref, trip, tab: MainTab.tripPlanner),
        onNameChanged: (name) => handleRenameTrip(context, ref, trip, name),
        onDelete: () => handleDeleteTrip(context, ref, trip),
      ),
    );
  }
}
