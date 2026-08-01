import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// One day's tile in [TripDetailsPage]'s horizontal day selector — date
/// badge + weekday label, plus the day's temperature (from the trip plan
/// itself) when available.
class TripDayCard extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;
  final double? temperatureC;

  const TripDayCard({
    super.key,
    required this.date,
    required this.isSelected,
    required this.onTap,
    this.temperatureC,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 95,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selectionTint : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: AppTextStyle.bold14.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(width: 1, height: 24, color: AppColors.borderSubtle),
                const SizedBox(width: 6),
                Text(
                  DateFormat('E').format(date),
                  style: AppTextStyle.bold14.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (temperatureC != null) ...[
              const SizedBox(height: 6),
              Text(
                '${temperatureC!.round()}°C',
                style: AppTextStyle.regular12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
