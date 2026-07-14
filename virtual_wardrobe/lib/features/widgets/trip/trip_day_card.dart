import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/weather_provider.dart';

/// One day's tile in [TripDetailsPage]'s horizontal day selector — date
/// badge + weekday label, plus a weather icon/temperature range when
/// forecast data is available for that day.
class TripDayCard extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;
  final int? weatherCode;
  final double? lowTemp;
  final double? highTemp;

  const TripDayCard({
    super.key,
    required this.date,
    required this.isSelected,
    required this.onTap,
    this.weatherCode,
    this.lowTemp,
    this.highTemp,
  });

  bool get _hasWeather =>
      weatherCode != null && lowTemp != null && highTemp != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 95,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x5CC6C0AB) : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                      color: AppColors.textPrimaryInv,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(width: 1, height: 24, color: AppColors.dividerSubtle),
                const SizedBox(width: 6),
                Text(
                  DateFormat('E').format(date),
                  style: AppTextStyle.bold14.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (_hasWeather) ...[
              const SizedBox(height: 6),
              Icon(
                WeatherData.iconFromCondition(
                  WeatherData.conditionFromCode(weatherCode!),
                ),
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 4),
              Text(
                '${lowTemp!.round()}°C - ${highTemp!.round()}°C',
                style: AppTextStyle.regular12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
