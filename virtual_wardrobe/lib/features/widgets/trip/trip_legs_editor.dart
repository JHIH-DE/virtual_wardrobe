import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/trip_plan.dart';
import '../../location_picker_page.dart';
import 'trip_leg_date_range_picker.dart';

/// Lets the user build up the list of legs (location + date range) for a
/// trip. Reads/writes through [legsNotifier] so the dialog that hosts this
/// widget can read the latest value when its own Save button is pressed.
class TripLegsEditor extends StatefulWidget {
  final ValueNotifier<List<TripLeg>> legsNotifier;

  const TripLegsEditor({super.key, required this.legsNotifier});

  @override
  State<TripLegsEditor> createState() => _TripLegsEditorState();
}

class _TripLegsEditorState extends State<TripLegsEditor> {
  List<TripLeg> get _legs => widget.legsNotifier.value;

  void _update(List<TripLeg> next) {
    setState(() => widget.legsNotifier.value = next);
  }

  Future<void> _addLeg() async {
    final location = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (location is! LocationResult) return;
    if (!mounted) return;

    final range = await showTripLegDateRangePicker(
      context: context,
      occupiedRanges: _legs.map((l) => l.dateRange).toList(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialVisibleMonth: _legs.isEmpty ? null : _legs.last.dateRange.end,
    );
    if (range == null) return;

    _update([..._legs, TripLeg(location: location, dateRange: range)]);
  }

  Future<void> _editLegDate(int index) async {
    final leg = _legs[index];
    final otherRanges = [
      for (int i = 0; i < _legs.length; i++)
        if (i != index) _legs[i].dateRange,
    ];
    final range = await showTripLegDateRangePicker(
      context: context,
      occupiedRanges: otherRanges,
      initialDateRange: leg.dateRange,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (range == null) return;

    final next = [..._legs];
    next[index] = leg.copyWith(dateRange: range);
    _update(next);
  }

  void _removeLeg(int index) {
    final next = [..._legs]..removeAt(index);
    _update(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _legs.length; i++) ...[
          if (i != 0) const SizedBox(height: 12),
          _buildLegRow(i),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _addLeg,
          icon: const Icon(Icons.add, size: 18, color: AppColors.accent),
          label: const Text('Add Location'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTextStyle.regular14.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegRow(int index) {
    final leg = _legs[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leg.location.name,
                  style: AppTextStyle.semibold14,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _editLegDate(index),
                  child: Text(
                    "${DateFormat('MM/dd').format(leg.dateRange.start)} - "
                    "${DateFormat('MM/dd').format(leg.dateRange.end)}",
                    style: AppTextStyle.regular13.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 18,
              color: AppColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _legs.length > 1 ? () => _removeLeg(index) : null,
          ),
        ],
      ),
    );
  }
}
