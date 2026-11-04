import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Pill-shaped search input with a leading search glyph and a clear button
/// that appears once there is text.
class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Off when the host offers its own clear control.
  final bool showClearButton;

  /// Fixed height, e.g. to match an [ActionDisc] beside it in a toolbar.
  /// Null keeps the standard field height.
  final double? height;

  const AppSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.showClearButton = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(999)),
      borderSide: BorderSide(color: AppColors.borderSubtle),
    );
    final height = this.height;
    final field = TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      // Lets the fill and border take the full fixed height.
      expands: height != null,
      maxLines: height != null ? null : 1,
      textAlignVertical: TextAlignVertical.center,
      style: AppTextStyle.medium16,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyle.medium16.copyWith(color: AppColors.hintText),
        filled: true,
        fillColor: AppColors.surface,
        constraints: height != null
            ? null
            : const BoxConstraints(minHeight: AppDimens.tappableFieldHeight),
        contentPadding: EdgeInsets.symmetric(vertical: height != null ? 0 : 12),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 16, right: 8),
          child: Icon(
            Icons.search,
            size: AppDimens.iconMediumSize,
            color: AppColors.icon,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minHeight: 0),
        suffixIconConstraints: height != null
            ? const BoxConstraints(minHeight: 0)
            : null,
        suffixIcon: !showClearButton
            ? null
            : ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    constraints: height != null
                        ? BoxConstraints.tightFor(width: height, height: height)
                        : null,
                    padding: height != null ? EdgeInsets.zero : null,
                    tooltip: AppLocalizations.of(context).clear,
                    icon: const Icon(
                      Icons.cancel,
                      size: AppDimens.iconSmallSize,
                      color: AppColors.hintText,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  );
                },
              ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
    );
    if (height == null) return field;
    return SizedBox(height: height, child: field);
  }
}
