import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
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
import '../widgets/common/overlays/empty_state_placeholder.dart';
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

/// Shows the "New Trip" creation flow (location/date form, then weather
/// prefetch + create call) and adds the result to [tripsProvider]. Shared
/// between [TripsPage]'s own "+" and any other entry point (e.g. the
/// Home page's quick-actions menu).
Future<void> handleCreateTrip(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onCreated,
}) async {
  final l10n = AppLocalizations.of(context);
  // Captured up front: `context` can't be trusted for navigation after the
  // create dialog + the network round-trips below, and the loading overlay
  // must be popped from the same navigator that showDialog pushes it onto.
  final navigator = Navigator.of(context, rootNavigator: true);

  final input = await showDialog<Trip>(
    context: context,
    barrierDismissible: false,
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
    final initialData = await TripDetailsPage.preload(newTrip);

    navigator.pop(); // close loading indicator
    // Switch the shell to the Trips tab first, so popping back off Trip
    // Details lands there regardless of where creation was started from.
    onCreated?.call();
    // Trip Details goes on the stack first (unseen — no await between the
    // two pushes, so only one transition actually animates) so that leaving
    // the Suitcase page pushed on top of it via its app-bar back button
    // lands on Trip Details, not wherever trip creation was started from.
    navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            TripDetailsPage(trip: newTrip, initialData: initialData),
      ),
    );
    navigator.push(
      MaterialPageRoute(
        builder: (_) => TripSuitcasePage(trip: newTrip, justCreated: true),
      ),
    );
  } on AuthExpiredException {
    navigator.pop(); // close loading indicator
    if (context.mounted) await AuthExpiredHandler.handle(context);
  } catch (e) {
    navigator.pop(); // close loading indicator
    debugLog('Failed to create trip: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.failedToCreateTrip)));
    }
  }
}

/// Renames a trip in place and reflects it in [tripsProvider]. Shared
/// between [TripsPage]'s own card and any other list-style trip card (e.g.
/// the Home page's). Destination/activity edits and deletion-with-
/// navigation live on [TripDetailsPage]'s own app bar menu instead — a
/// list card only ever needs the lightweight rename+delete pair.
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).failedToUpdateTrip)),
    );
  }
}

/// Deletes a trip (with a loading overlay for the round trip) and removes
/// it from [tripsProvider]. Shared between [TripsPage] and any other list
/// entry point that can delete a trip (e.g. the Home page's trip card) —
/// unlike [TripDetailsPage]'s own delete action, there's no page to pop out
/// of here, just a card to drop from the list.
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).failedToDeleteTrip)),
    );
  }
}

/// Opens [TripDetailsPage] with a shell loading overlay covering the preload.
/// Shared between [TripsPage]'s own cards and the Home page's trip card —
/// [tab] just picks which `MainTab`'s overlay to drive.
Future<void> openTripDetails(
  BuildContext context,
  WidgetRef ref,
  Trip trip, {
  required MainTab tab,
}) async {
  final l10n = AppLocalizations.of(context);
  MainShellScope.of(
    context,
  )?.setLoading(true, label: l10n.loadingTripEllipsis, tab: tab);
  try {
    final data = await TripDetailsPage.preload(trip);
    if (!context.mounted) return;
    MainShellScope.of(context)?.setLoading(false, tab: tab);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(trip: trip, initialData: data),
      ),
    );
  } on AuthExpiredException {
    if (!context.mounted) return;
    MainShellScope.of(context)?.setLoading(false, tab: tab);
    await AuthExpiredHandler.handle(context);
  } catch (e) {
    if (!context.mounted) return;
    MainShellScope.of(context)?.setLoading(false, tab: tab);
    debugLog('Failed to load trip details: $e');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.failedToLoadTripDetails)));
  }
}

/// Creates the trip plan record and returns it as a [Trip] — per-day
/// temperature isn't sent; the backend derives every day from [legs] and
/// fills it in on its own (forecast within its window, historical average
/// otherwise).
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

  /// Splits [trips] into Ongoing / Upcoming / Past sections (each ordered
  /// by how soon they happen — Ongoing/Upcoming ascending by start date,
  /// Past descending so the most recently finished trip shows first), and
  /// interleaves a [LabeledDivider] header before each non-empty section.
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
      // No extra gap needed here even between sections — every card
      // (including each section's last) already ends in its own
      // AppDimens.sectionSpacing via _buildTripCard's bottom padding.
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
      // Dead-centered in the whole body area (not just its own natural
      // size) — same treatment as Trip Suitcase's own empty state; not the
      // old "60% of screen height" guess.
      fillAvailableSpace: true,
      // Trips is a main tab — MainNavBar floats over the bottom of its
      // Scaffold.body rather than shrinking it (see bottomInset's doc).
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
