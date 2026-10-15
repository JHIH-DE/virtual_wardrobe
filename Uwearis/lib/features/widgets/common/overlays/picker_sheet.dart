import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../app_divider.dart';

/// Header for picker sheets: drag handle, title row (optional [trailing]
/// action) and divider. Put the list after it in the same [Column].
class PickerSheetHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;

  const PickerSheetHeader(
    this.title, {
    super.key,
    this.description,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetDragHandle(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyle.bold20)),
            ?trailing,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const AppDivider(spacing: 8, color: AppColors.dividerSubtle),
      ],
    );
  }
}

class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.overlaySubtle,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

/// Flutter caps a modal sheet at 9/16 of the screen; [fitContent] lets it
/// grow to its content (still below the status bar).
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
  bool fitContent = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: fitContent,
    useSafeArea: fitContent,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) =>
        Padding(padding: padding, child: builder(sheetContext)),
  );
}

/// Resolves to the tapped option, or `null` if dismissed.
Future<T?> showSingleChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T) labelOf,
}) {
  return showPickerSheet<T>(
    context,
    fitContent: true,
    builder: (sheetContext) => RadioGroup<T>(
      groupValue: selected,
      onChanged: (v) => Navigator.pop(sheetContext, v),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PickerSheetHeader(title),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final option in options)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      labelOf(option),
                      style: option == selected
                          ? AppTextStyle.bold16
                          : AppTextStyle.regular16,
                    ),
                    trailing: Radio<T>(
                      value: option,
                      activeColor: AppColors.accent,
                    ),
                    onTap: () => Navigator.pop(sheetContext, option),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
