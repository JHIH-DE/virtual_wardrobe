import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../app/theme/app_colors.dart';

class CustomDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final Color? dropdownColor;
  final double? menuMaxHeight;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.dropdownColor,
    this.menuMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField2<T>(
      value: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,

      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textBoxBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textBoxBorder, width: 2),
        ),
      ),

      buttonStyleData: ButtonStyleData(
        height: 48,
        padding: EdgeInsets.zero,
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
        icon: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Image.asset(
            'assets/images/arrow_down.png',
            height: 20,
          ),
        ),
      ),
    );
  }
}