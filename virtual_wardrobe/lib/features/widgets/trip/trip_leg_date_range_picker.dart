import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// A date-range picker that greys out and disables any day already covered
/// by [occupiedRanges] (e.g. another trip leg), so the user can see at a
/// glance which dates are already taken before picking a new range.
Future<DateTimeRange?> showTripLegDateRangePicker({
  required BuildContext context,
  required List<DateTimeRange> occupiedRanges,
  DateTimeRange? initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialVisibleMonth,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _TripLegDateRangePickerDialog(
      occupiedRanges: occupiedRanges,
      initialDateRange: initialDateRange,
      firstDate: firstDate,
      lastDate: lastDate,
      initialVisibleMonth: initialVisibleMonth,
    ),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class _TripLegDateRangePickerDialog extends StatefulWidget {
  final List<DateTimeRange> occupiedRanges;
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialVisibleMonth;

  const _TripLegDateRangePickerDialog({
    required this.occupiedRanges,
    required this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    this.initialVisibleMonth,
  });

  @override
  State<_TripLegDateRangePickerDialog> createState() =>
      _TripLegDateRangePickerDialogState();
}

class _TripLegDateRangePickerDialogState
    extends State<_TripLegDateRangePickerDialog> {
  late DateTime _visibleMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialDateRange == null
        ? null
        : _dateOnly(widget.initialDateRange!.start);
    _rangeEnd = widget.initialDateRange == null
        ? null
        : _dateOnly(widget.initialDateRange!.end);
    final anchor =
        _rangeStart ??
        (widget.initialVisibleMonth != null
            ? _dateOnly(widget.initialVisibleMonth!)
            : _dateOnly(widget.firstDate));
    _visibleMonth = DateTime(anchor.year, anchor.month);
  }

  bool _isOccupied(DateTime day) {
    for (final range in widget.occupiedRanges) {
      final start = _dateOnly(range.start);
      final end = _dateOnly(range.end);
      if (!day.isBefore(start) && !day.isAfter(end)) return true;
    }
    return false;
  }

  bool _isOutOfBounds(DateTime day) =>
      day.isBefore(_dateOnly(widget.firstDate)) ||
      day.isAfter(_dateOnly(widget.lastDate));

  bool _isDisabled(DateTime day) => _isOutOfBounds(day) || _isOccupied(day);

  bool _hasOccupiedBetween(DateTime start, DateTime end) {
    var d = _dateOnly(start);
    final endOnly = _dateOnly(end);
    while (!d.isAfter(endOnly)) {
      if (_isOccupied(d)) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  void _onDayTap(DateTime day) {
    if (_isDisabled(day)) return;
    setState(() {
      if (_rangeStart == null || _rangeEnd != null) {
        _rangeStart = day;
        _rangeEnd = null;
      } else if (day.isBefore(_rangeStart!)) {
        _rangeStart = day;
      } else if (_hasOccupiedBetween(_rangeStart!, day)) {
        // Can't span over an occupied day; start a fresh selection here.
        _rangeStart = day;
        _rangeEnd = null;
      } else {
        _rangeEnd = day;
      }
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _rangeStart != null && _rangeEnd != null;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Dates', style: AppTextStyle.dialogTitle),
            const SizedBox(height: 6),
            Text(
              _rangeStart == null
                  ? 'Start Date – End Date'
                  : _rangeEnd == null
                  ? '${_fmt(_rangeStart!)} – End Date'
                  : '${_fmt(_rangeStart!)} – ${_fmt(_rangeEnd!)}',
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_visibleMonth),
                  style: AppTextStyle.bold16,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            _buildWeekdayHeader(),
            const SizedBox(height: 4),
            _buildMonthGrid(),
            const SizedBox(height: 12),
            Row(
              children: [
                _legendDot(AppColors.dividerSubtle, 'Booked'),
                const SizedBox(width: 16),
                _legendDot(AppColors.primary, 'Selected'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 1.6),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canConfirm
                        ? () => Navigator.pop(
                            context,
                            DateTimeRange(start: _rangeStart!, end: _rangeEnd!),
                          )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.nearBlack,
                      disabledBackgroundColor: AppColors.dividerSubtle,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: AppTextStyle.regular12.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMonthGrid() {
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leadingBlanks = firstOfMonth.weekday % 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: leadingBlanks + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();
        final day = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          index - leadingBlanks + 1,
        );
        return _buildDayCell(day);
      },
    );
  }

  Widget _buildDayCell(DateTime day) {
    final disabled = _isDisabled(day);
    final occupied = _isOccupied(day);
    final isStart = _rangeStart != null && day.isAtSameMomentAs(_rangeStart!);
    final isEnd = _rangeEnd != null && day.isAtSameMomentAs(_rangeEnd!);
    final inRange =
        _rangeStart != null &&
        _rangeEnd != null &&
        day.isAfter(_rangeStart!) &&
        day.isBefore(_rangeEnd!);

    Color? background;
    Color textColor = Colors.black;
    if (occupied) {
      background = AppColors.dividerSubtle;
      textColor = AppColors.textSecondary;
    } else if (isStart || isEnd) {
      background = AppColors.primary;
      textColor = Colors.white;
    } else if (inRange) {
      background = AppColors.primary.withValues(alpha: 0.15);
    }
    if (_isOutOfBounds(day) && !occupied) {
      textColor = AppColors.textSecondary.withValues(alpha: 0.4);
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: disabled ? null : () => _onDayTap(day),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Text(
            '${day.day}',
            style: AppTextStyle.regular14.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyle.regular12.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) => DateFormat('MM/dd').format(d);
}
