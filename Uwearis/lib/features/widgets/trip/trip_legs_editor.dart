import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/date_locale.dart';
import '../../../data/location_result.dart';
import '../../../data/trip.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../pages/common/location_picker_page.dart';
import '../common/buttons/circle_icon_button.dart';
import '../common/app_divider.dart';
import 'trip_leg_date_range_picker.dart';

/// Edits a trip's legs through [legsNotifier], which the hosting dialog
/// reads on submit.
class TripLegsEditor extends StatefulWidget {
  final ValueNotifier<List<TripLeg>> legsNotifier;

  /// Lets the last leg be removed too: a new trip's own submit gate already
  /// requires a leg, while a saved trip must always keep one.
  final bool allowsEmpty;

  const TripLegsEditor({
    super.key,
    required this.legsNotifier,
    this.allowsEmpty = false,
  });

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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _legs.length; i++) ...[
            if (i != 0) const AppDivider(spacing: 0),
            _buildLegRow(i),
          ],
          if (_legs.isNotEmpty) const AppDivider(spacing: 0),
          _buildAddRow(l10n),
        ],
      ),
    );
  }

  Widget _buildLegRow(int index) {
    final leg = _legs[index];
    final dateFormat = DateFormat.MMMd(dateLocaleOf(context));
    return InkWell(
      onTap: () => _editLegDate(index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leg.location.name,
                    style: AppTextStyle.semibold16,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${dateFormat.format(leg.dateRange.start)} – "
                    "${dateFormat.format(leg.dateRange.end)}",
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            CircleIconButton(
              icon: Icons.close,
              discAlignment: Alignment.centerRight,
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              enabled: widget.allowsEmpty || _legs.length > 1,
              onPressed: () => _removeLeg(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRow(AppLocalizations l10n) {
    return InkWell(
      onTap: _addLeg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.add, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.addLocation,
                  style: AppTextStyle.medium14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
