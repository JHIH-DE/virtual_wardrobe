import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/location_result.dart';
import '../../../data/trip.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../pages/location_picker_page.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/cards/card_corner_badge.dart';
import '../common/field_label.dart';
import 'trip_leg_date_range_picker.dart';

/// Edits a trip's legs through [legsNotifier], which the hosting dialog
/// reads on submit. With a [label], the add button sits beside it instead
/// of under the legs.
class TripLegsEditor extends StatefulWidget {
  final ValueNotifier<List<TripLeg>> legsNotifier;
  final String? label;

  const TripLegsEditor({super.key, required this.legsNotifier, this.label});

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
    final l10n = AppLocalizations.of(context);
    final label = widget.label;
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Expanded(child: FieldLabel(label.toUpperCase())),
                AccentPillButton(label: l10n.addAction, onPressed: _addLeg),
              ],
            ),
            if (_legs.isNotEmpty) const SizedBox(height: 4),
          ],
          for (int i = 0; i < _legs.length; i++) ...[
            if (i != 0) const SizedBox(height: 12),
            _buildLegRow(i),
          ],
          if (label == null) ...[
            if (_legs.isNotEmpty) const SizedBox(height: 12),
            Center(
              child: AccentPillButton(
                label: l10n.addLocation,
                onPressed: _addLeg,
              ),
            ),
          ],
        ],
      ),
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
          CardCornerBadge(
            icon: Icons.close,
            backgroundColor: AppColors.placeholderSurface,
            iconColor: AppColors.icon,
            hitTargetSize: const Size(24, AppDimens.minTouchTarget),
            onTap: _legs.length > 1 ? () => _removeLeg(index) : null,
          ),
        ],
      ),
    );
  }
}
