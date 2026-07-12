import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import 'selectable_chip.dart';

class CategorySelector extends StatelessWidget {
  final List<GarmentCategory> categories;
  final GarmentCategory selectedCategory;
  final ValueChanged<GarmentCategory> onSelected;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final category = categories[i];
            return SelectableChip(
              label: category.label,
              selected: category == selectedCategory,
              onTap: () => onSelected(category),
              selectedColor: AppColors.nearBlack,
              unselectedFillColor: Colors.white,
              unselectedBorderColor: Colors.black12,
              unselectedTextColor: Colors.black,
              textStyle: AppTextStyle.bold16,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
            );
          },
        ),
      ),
    );
  }
}
