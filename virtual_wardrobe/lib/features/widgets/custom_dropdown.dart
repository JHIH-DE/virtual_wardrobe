import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';

const _kBorderColor = Color(0xFF2B3A8C);
const _kBorderRadius = 18.0;
const _kFieldHeight = 56.0;

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final Color? dropdownColor;
  final double? menuMaxHeight;

  const CustomDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.dropdownColor,
    this.menuMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _decoration().copyWith(contentPadding: EdgeInsets.zero),
      child: SizedBox(
        height: _kFieldHeight,
        child: DropdownButtonHideUnderline(
          child: DropdownButton2<T>(
            value: value,
            isExpanded: true,
            hint: hint != null
                ? Text(
                    hint!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  )
                : null,
            items: items,
            onChanged: onChanged,
            buttonStyleData: const ButtonStyleData(
              // DropdownButton2 adds 16px horizontal padding to the IndexedStack
              // (hint/selected item) via _getMenuHorizontalPadding(). Compensate
              // so the text lands at 20px from each edge: left = 20 - 16 = 4.
              padding: EdgeInsets.only(left: 4, right: 20),
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: menuMaxHeight ?? 400,
              decoration: BoxDecoration(
                color: dropdownColor ?? AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            iconStyleData: IconStyleData(
              iconSize: 20,
              icon: Image.asset(
                'assets/images/arrow_down.png',
                width: 20,
                height: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Date picker styled to match [CustomDropdown].
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
    final hasValue = _label.isNotEmpty;
    return GestureDetector(
      onTap: onChanged != null ? () => _pick(context) : null,
      child: InputDecorator(
        decoration: _decoration().copyWith(contentPadding: EdgeInsets.zero),
        child: SizedBox(
          height: _kFieldHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? _label : (hint ?? ''),
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/arrow_down.png',
                  width: 20,
                  height: 20,
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

InputDecoration _decoration() => const InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(_kBorderRadius)),
        borderSide: BorderSide(color: _kBorderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(_kBorderRadius)),
        borderSide: BorderSide(color: _kBorderColor, width: 2),
      ),
    );
