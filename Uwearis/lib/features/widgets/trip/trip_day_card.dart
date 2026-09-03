import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

/// One day's tile in [TripDetailsPage]'s horizontal day selector — date
/// badge + weekday label, plus the day's temperature range (from the trip
/// plan itself) when available. Selection only changes on tap.
class TripDayCard extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final double? temperatureMaxC;
  final double? temperatureMinC;
  final VoidCallback? onTap;

  const TripDayCard({
    super.key,
    required this.date,
    required this.isSelected,
    this.temperatureMaxC,
    this.temperatureMinC,
    this.onTap,
  });

  String? get _temperatureLabel {
    final max = temperatureMaxC?.round();
    final min = temperatureMinC?.round();
    if (max != null && min != null) return '$min°–$max°C';
    if (max != null) return '$max°C';
    if (min != null) return '$min°C';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: _buildCard());
  }

  Widget _buildCard() {
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.pageBackground
            : AppColors.interactiveArea,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: isSelected
            ? Border.all(color: AppColors.borderStrong, width: 1.5)
            : Border.all(color: AppColors.shadowFaint, width: 1),
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
          // scaleDown so a wide weekday abbreviation (or a wider glyph set
          // under a different locale/font) shrinks to fit the fixed card
          // width instead of overflowing the row.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
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
          ),
          if (_temperatureLabel != null) ...[
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_temperatureLabel!, style: AppTextStyle.semibold14),
            ),
          ],
        ],
      ),
    );
  }
}
