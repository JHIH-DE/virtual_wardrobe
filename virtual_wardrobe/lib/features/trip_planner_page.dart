import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/trips_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/trip_plan_service.dart';
import '../core/utils/debug_log.dart';
import '../data/trip_plan.dart';
import 'trip_details_page.dart';
import 'widgets/trip_plan_create_dialog.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/page_app_bar.dart';
import 'widgets/trip_plan_card.dart';

class TripPlannerPage extends ConsumerStatefulWidget {
  const TripPlannerPage({super.key});

  @override
  ConsumerState<TripPlannerPage> createState() => _TripPlannerPageState();
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

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<List<TripPlan>> tripsAsync,
  ) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: const PageAppBar(title: 'Trip Planner'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan Your Next Adventure',
                          style: AppTextStyle.bold18,
                        ),
                        Text(
                          'Add locations and see forecasts',
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _handleCreateTrip(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('New Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tripsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(e),
                data: (trips) => RefreshIndicator(
                  onRefresh: () => ref.read(tripsProvider.notifier).refresh(),
                  child: trips.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.beach_access,
                                      size: 64,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No trips planned yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
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
                                onDelete: () =>
                                    _handleDeleteTrip(context, ref, trip),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    if (e is AuthExpiredException) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(e.toString(), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.read(tripsProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateTrip(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<TripPlan>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TripPlanCreateDialog(),
    );
    if (input == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final id = await TripPlanService().createTripPlan(
        name: input.name,
        location: input.location.name,
        startDate: DateFormat('yyyy-MM-dd').format(input.dateRange.start),
        endDate: DateFormat('yyyy-MM-dd').format(input.dateRange.end),
        timezone: input.location.timezone,
        purpose: input.purpose,
        days: const [],
      );

      if (!context.mounted) return;
      Navigator.pop(context); // close loading indicator
      ref.read(tripsProvider.notifier).add(
            TripPlan(
              id: id.toString(),
              name: input.name,
              dateRange: input.dateRange,
              location: input.location,
              purpose: input.purpose,
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
