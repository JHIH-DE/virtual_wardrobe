import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/outfit.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/filter_button.dart';
import '../common/fields/number_stepper.dart';

/// The suitable-temperature section of the outfit tags sheet: a lowest and a
/// highest stepper, each able to step past its end into "No limit". Only
/// valid ranges can be reached (`min < max`, not both open), so there is
/// nothing to reject on save.
class OutfitTemperatureEditor extends StatefulWidget {
  final OutfitTemperature initial;

  /// The edit to save, or null when there is nothing to change.
  final ValueChanged<OutfitTemperatureEdit?> onChanged;

  const OutfitTemperatureEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  /// The backend's accepted range.
  static const int lowestC = -30;
  static const int highestC = 50;

  /// Width of the range a stepper jumps to when leaving "No limit" — the
  /// automatic ranges are this wide.
  static const int defaultSpanC = 6;

  @override
  State<OutfitTemperatureEditor> createState() =>
      _OutfitTemperatureEditorState();
}

class _OutfitTemperatureEditorState extends State<OutfitTemperatureEditor> {
  late int? _min = widget.initial.minC;
  late int? _max = widget.initial.maxC;

  /// A saved manual range the user asked to recalculate.
  bool _resetPending = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool get _initiallyManual =>
      widget.initial.source == OutfitTemperatureSource.manual;

  bool get _changedFromInitial =>
      _min != widget.initial.minC || _max != widget.initial.maxC;

  bool get _isManual => _initiallyManual ? !_resetPending : _changedFromInitial;

  OutfitTemperatureEdit? get _edit {
    if (_initiallyManual && _resetPending) return (minC: null, maxC: null);
    return _changedFromInitial ? (minC: _min, maxC: _max) : null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipSheetSectionHeader(
          _l10n.outfitTemperatureLabel,
          trailing: _isManual || _resetPending
              ? TextButton(
                  onPressed: _resetPending ? _cancelReset : _resetToAuto,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    textStyle: AppTextStyle.semibold16,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _resetPending
                        ? _l10n.outfitTemperatureCustomize
                        : _l10n.outfitTemperatureResetAuto,
                  ),
                )
              : null,
        ),
        if (_resetPending)
          _buildHint(_l10n.outfitTemperatureAutoPending)
        else ...[
          _buildStepperRow(
            label: _l10n.outfitTemperatureLowest,
            value: _min,
            onDecrement: _canLowerMin ? () => _setMin(_lowerMin()) : null,
            onIncrement: _canRaiseMin ? () => _setMin(_raiseMin()) : null,
          ),
          _buildStepperRow(
            label: _l10n.outfitTemperatureHighest,
            value: _max,
            onDecrement: _canLowerMax ? () => _setMax(_lowerMax()) : null,
            onIncrement: _canRaiseMax ? () => _setMax(_raiseMax()) : null,
          ),
        ],
      ],
    );
  }

  /// Label beside the stepper; above it once both no longer fit on one
  /// line. Sized for the widest value label, so it doesn't jump while
  /// stepping.
  Widget _buildStepperRow({
    required String label,
    required int? value,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    final labelText = Text(label, style: AppTextStyle.semibold16);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stepperWidth = [
          _valueLabel(null),
          _valueLabel(OutfitTemperatureEditor.lowestC),
        ].map((v) => NumberStepper.tileWidthFor(context, v)).reduce(math.max);
        final stepper = SizedBox(
          width: math.min(stepperWidth, constraints.maxWidth),
          child: NumberStepper(
            variant: NumberStepperVariant.tile,
            valueLabel: _valueLabel(value),
            onDecrement: onDecrement,
            onIncrement: onIncrement,
          ),
        );
        final painter = TextPainter(
          text: TextSpan(text: label, style: AppTextStyle.semibold16),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fits =
            painter.width + _labelGap + stepperWidth <= constraints.maxWidth;
        painter.dispose();
        if (fits) {
          return Row(
            children: [
              Expanded(child: labelText),
              const SizedBox(width: _labelGap),
              stepper,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 8), child: labelText),
            stepper,
          ],
        );
      },
    );
  }

  static const double _labelGap = 12;

  Widget _buildHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  String _valueLabel(int? value) =>
      value == null ? _l10n.outfitTemperatureNoLimit : '$value°C';

  // Lowest: below [lowestC] is "No limit", unless the highest already is.
  bool get _canLowerMin =>
      _min != null && (_min! > OutfitTemperatureEditor.lowestC || _max != null);

  int? _lowerMin() =>
      _min! > OutfitTemperatureEditor.lowestC ? _min! - 1 : null;

  bool get _canRaiseMin {
    if (_min == null) return true;
    final ceiling = (_max ?? OutfitTemperatureEditor.highestC + 1) - 1;
    return _min! < ceiling;
  }

  int _raiseMin() {
    if (_min != null) return _min! + 1;
    final ceiling = (_max ?? OutfitTemperatureEditor.highestC + 1) - 1;
    final target = (_max ?? 26) - OutfitTemperatureEditor.defaultSpanC;
    return target.clamp(OutfitTemperatureEditor.lowestC, ceiling);
  }

  // Highest: above [highestC] is "No limit", unless the lowest already is.
  bool get _canRaiseMax =>
      _max != null &&
      (_max! < OutfitTemperatureEditor.highestC || _min != null);

  int? _raiseMax() =>
      _max! < OutfitTemperatureEditor.highestC ? _max! + 1 : null;

  bool get _canLowerMax {
    if (_max == null) return true;
    final floor = (_min ?? OutfitTemperatureEditor.lowestC - 1) + 1;
    return _max! > floor;
  }

  int _lowerMax() {
    if (_max != null) return _max! - 1;
    final floor = (_min ?? OutfitTemperatureEditor.lowestC - 1) + 1;
    final target = (_min ?? 14) + OutfitTemperatureEditor.defaultSpanC;
    return target.clamp(floor, OutfitTemperatureEditor.highestC);
  }

  void _setMin(int? value) {
    setState(() => _min = value);
    widget.onChanged(_edit);
  }

  void _setMax(int? value) {
    setState(() => _max = value);
    widget.onChanged(_edit);
  }

  void _resetToAuto() {
    setState(() {
      if (_initiallyManual) {
        _resetPending = true;
      } else {
        _min = widget.initial.minC;
        _max = widget.initial.maxC;
      }
    });
    widget.onChanged(_edit);
  }

  void _cancelReset() {
    setState(() => _resetPending = false);
    widget.onChanged(_edit);
  }
}
