import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/trips_provider.dart';
import '../data/trip_plan.dart';
import 'widgets/create_trip_dialog.dart';
import 'widgets/page_app_bar.dart';
import 'widgets/trip_plan_card.dart';

class TripPlannerPage extends ConsumerWidget {
  const TripPlannerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);

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
                    onPressed: () async {
                      final result = await showDialog<TripPlan>(
                        context: context,
                        builder: (_) => const CreateTripDialog(),
                      );
                      if (result != null) {
                        ref.read(tripsProvider.notifier).add(result);
                      }
                    },
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
              child: trips.isEmpty
                  ? Center(
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
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
                            onDelete: () => ref
                                .read(tripsProvider.notifier)
                                .remove(trip.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
