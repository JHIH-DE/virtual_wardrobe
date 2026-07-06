import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/trip_plan.dart';
import '../trip_details_page.dart';
import 'app_dialog.dart';

class TripPlanCard extends StatelessWidget {
  final TripPlan trip;
  final VoidCallback onDelete;

  const TripPlanCard({super.key, required this.trip, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        "${DateFormat('MMM d').format(trip.dateRange.start)} - "
        "${DateFormat('MMM d, yyyy').format(trip.dateRange.end)}";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TripDetailsPage(trip: trip)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trip.name,
                    style: AppTextStyle.bold24.copyWith(color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AppDialog(
                        title: 'Delete Trip',
                        body: 'Are you sure you want to delete this trip?',
                        primaryLabel: 'Delete',
                        onPrimary: () => Navigator.pop(ctx, true),
                        secondaryLabel: 'Cancel',
                        onSecondary: () => Navigator.pop(ctx, false),
                      ),
                    ).then((confirmed) {
                      if (confirmed == true) onDelete();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.location.name,
                    style: AppTextStyle.regular16.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: AppTextStyle.regular16.copyWith(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "View Plan",
                  style: AppTextStyle.regular12.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
