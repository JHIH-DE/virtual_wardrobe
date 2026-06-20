import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

InputDecoration appInputDecoration({
  String? hint,
  String? label,
  String? suffixText,
  Widget? prefixIcon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    labelText: label,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    suffixText: suffixText,
    suffixStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    suffix: suffix,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.textBoxBorder, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final String? label;
  final String? suffixText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final int? maxLines;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    this.controller,
    this.hint = '',
    this.label,
    this.suffixText,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.maxLines = 1,
    this.onTap,
    this.focusNode,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      style: AppTextStyle.bold16,
      decoration: appInputDecoration(
        hint: hint,
        label: label,
        suffixText: suffixText,
        prefixIcon: prefixIcon,
      ),
    );
  }
}
