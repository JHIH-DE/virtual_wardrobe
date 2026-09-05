import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/occasion_type.dart';
import '../../../../l10n/occasion_type_localization.dart';
import 'picker_sheet.dart';

/// Shared "pick one occasion" bottom sheet — Lifestyle's weekly routine and
/// Add Outfit's "Complete with AI" context both need the exact same
/// icon + label + radio list, just with a different [title] and starting
/// [current] value.
Future<OccasionType?> showOccasionPickerSheet(
  BuildContext context, {
  required OccasionType current,
  required String title,
}) {
  return showPickerSheet<OccasionType>(
    context,
    builder: (sheetContext) => RadioGroup<OccasionType>(
      groupValue: current,
      onChanged: (value) {
        if (value != null) Navigator.pop(sheetContext, value);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PickerSheetHeader(title),
          for (final occasion in OccasionType.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: occasion == current
                    ? BoxDecoration(
                        color: AppColors.accentTint,
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  occasion.icon,
                  size: 18,
                  color: occasion == current
                      ? AppColors.accent
                      : AppColors.icon,
                ),
              ),
              title: Text(
                occasion.localizedLabel(sheetContext),
                style: occasion == current
                    ? AppTextStyle.bold16
                    : AppTextStyle.regular16,
              ),
              trailing: Radio<OccasionType>(
                value: occasion,
                activeColor: AppColors.accent,
              ),
              onTap: () => Navigator.pop(sheetContext, occasion),
            ),
        ],
      ),
    ),
  );
}
