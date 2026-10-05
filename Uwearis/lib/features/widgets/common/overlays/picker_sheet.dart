import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../app_divider.dart';

/// Shared chrome for every "pick one from a list" bottom sheet in the app
/// (Occasion, Gender, Language, Color): a drag handle, a title row (with
/// an optional trailing action, e.g. Color's "Clear" button), and a
/// divider inset 24px from each side. Put the actual list/grid as further
/// children after it in the same [Column].
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

/// The small rounded drag handle shown at the top of every bottom sheet
/// that uses [showPickerSheet]'s chrome.
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

/// Opens a bottom sheet with the app's standard picker-sheet chrome —
/// surface background, rounded top corners, and [builder]'s content
/// (typically starting with a [PickerSheetHeader]).
///
/// By default Flutter caps a modal sheet at 9/16 of the screen. With
/// [fitContent] the sheet grows to its content's height instead (still kept
/// below the status bar).
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

/// The standard single-choice picker: [PickerSheetHeader] + one radio row
/// per option, the current [selected] in bold. Resolves to the tapped
/// option, or `null` when the sheet is dismissed without a choice.
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
          // Only scrolls when the options can't fit the whole screen.
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
