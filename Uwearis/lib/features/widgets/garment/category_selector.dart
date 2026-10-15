import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../common/fields/selectable_chip.dart';

class CategorySelector extends StatelessWidget implements PreferredSizeWidget {
  final List<GarmentCategory> categories;
  final GarmentCategory selectedCategory;
  final ValueChanged<GarmentCategory> onSelected;

  // 52 − 8 bottom padding = 44px rows, so each chip's tap target reaches
  // AppDimens.minTouchTarget around the ~38px pill.
  static const double _height = 52;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  /// Usable as an AppToolBar's `bottom:`, so the toolbar's shadow lands
  /// below the selector instead of across it.
  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.toolbarBackground,
      child: SizedBox(
        height: _height,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final category = categories[i];
            return SelectableChip(
              label: category.localizedLabel(context),
              selected: category == selectedCategory,
              onTap: () => onSelected(category),
              selectedColor: AppColors.primary,
              unselectedFillColor: AppColors.surface,
              unselectedBorderColor: AppColors.borderSubtle,
              unselectedTextColor: AppColors.textPrimary,
              textStyle: AppTextStyle.bold16,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            );
          },
        ),
      ),
    );
  }
}
