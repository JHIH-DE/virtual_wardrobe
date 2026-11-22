import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../common/fields/chip_tab_row.dart';

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
        child: ChipTabRow<GarmentCategory>(
          tabs: categories,
          selected: selectedCategory,
          labelOf: (category) => category.localizedLabel(context),
          onSelected: onSelected,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        ),
      ),
    );
  }
}
