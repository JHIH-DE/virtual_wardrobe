import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_text_field.dart';

/// Decimal-number input with a unit suffix (e.g. "cm", "kg").
class NumericUnitField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String unit;

  const NumericUnitField({
    super.key,
    required this.controller,
    required this.hint,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hint: hint,
      suffixText: unit,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
    );
  }
}
