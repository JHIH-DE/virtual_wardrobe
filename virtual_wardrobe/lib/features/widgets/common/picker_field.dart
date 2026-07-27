import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import 'app_text_field.dart';

// Matches AppTextField/appInputDecoration's defaults so mixed text-field/
// dropdown rows line up.
const _kBorderRadius = 14.0;
// Measured, not guessed — see AppTextField.
const _kFieldHeight = 48.0;

/// Date picker styled to match [PickerField].
class DateDropdownField extends StatelessWidget {
  final DateTime? value;
  final void Function(DateTime)? onChanged;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String Function(DateTime)? formatter;

  const DateDropdownField({
    super.key,
    required this.onChanged,
    this.value,
    this.hint,
    this.firstDate,
    this.lastDate,
    this.formatter,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(1990),
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime.now(),
    );
    if (picked != null) onChanged?.call(picked);
  }

  String get _label {
    if (value == null) return '';
    return formatter != null
        ? formatter!(value!)
        : DateFormat('yyyy/MM/dd').format(value!);
  }

  @override
  Widget build(BuildContext context) {
    return _TapToPickField(
      text: _label,
      hint: hint,
      onTap: onChanged != null ? () => _pick(context) : null,
    );
  }
}

/// Tap-to-open field (e.g. to show a bottom sheet picker) — shows [text] (or
/// [hint] when [text] is empty) with a trailing arrow, and calls [onTap]
/// (e.g. to open a bottom sheet picker) instead of an inline menu.
class PickerField extends StatelessWidget {
  final String text;
  final String? hint;
  final VoidCallback? onTap;

  const PickerField({
    super.key,
    required this.text,
    this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TapToPickField(text: text, hint: hint, onTap: onTap);
  }
}

class _TapToPickField extends StatelessWidget {
  final String text;
  final String? hint;
  final VoidCallback? onTap;

  const _TapToPickField({required this.text, this.hint, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasValue = text.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: _decoration().copyWith(contentPadding: EdgeInsets.zero),
        child: SizedBox(
          height: _kFieldHeight,
          child: Padding(
            // Measured empirically against AppTextField (this Row/Text/Image
            // layout has a few px of its own inherent offset, so the values
            // here aren't the raw target insets).
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? text : (hint ?? ''),
                    style: AppTextStyle.regular16.copyWith(
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/arrow_down.png',
                  width: AppDimens.iconSmallSize,
                  height: AppDimens.iconSmallSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared decoration ─────────────────────────────────────────────────────────

InputDecoration _decoration() => appInputDecoration(
  borderRadius: _kBorderRadius,
  borderColor: AppColors.borderStrong,
  focusedBorderColor: AppColors.borderStrong,
  focusedBorderWidth: 2,
);
