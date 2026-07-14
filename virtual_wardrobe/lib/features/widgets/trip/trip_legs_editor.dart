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
        for (int i = 0; i < _legs.length; i++) _buildLegRow(i),
        OutlinedButton.icon(
          onPressed: _addLeg,
          icon: const Icon(Icons.add),
          label: const Text('Add Location'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.primary),
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildLegRow(int index) {
    final leg = _legs[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leg.location.name,
                  style: AppTextStyle.bold14,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                GestureDetector(
                  onTap: () => _editLegDate(index),
                  child: Text(
                    "${DateFormat('MM/dd').format(leg.dateRange.start)} - "
                    "${DateFormat('MM/dd').format(leg.dateRange.end)}",
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _legs.length > 1 ? () => _removeLeg(index) : null,
          ),
        ],
      ),
    );
  }
}
