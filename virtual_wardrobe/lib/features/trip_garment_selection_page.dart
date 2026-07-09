import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../data/garment.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/garment_card.dart';
import 'widgets/page_app_bar.dart';

class TripGarmentSelectionPage extends StatefulWidget {
  final List<Garment> garments;
  final Set<int> initiallySelectedIds;

  const TripGarmentSelectionPage({
    super.key,
    required this.garments,
    required this.initiallySelectedIds,
  });

  @override
  State<TripGarmentSelectionPage> createState() =>
      _TripGarmentSelectionPageState();
}

class _TripGarmentSelectionPageState extends State<TripGarmentSelectionPage> {
  static const _categories = [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outer,
    GarmentCategory.onePiece,
    GarmentCategory.shoes,
    GarmentCategory.socks,
    GarmentCategory.accessory,
  ];

  late final Set<int> _selectedIds = {...widget.initiallySelectedIds};
  GarmentCategory _selectedCategory = GarmentCategory.top;

  void _toggle(Garment garment) {
    final id = garment.id;
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.garments
        .where((g) => g.category == _selectedCategory)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: const PageAppBar(title: 'Select Garments'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildCategorySelector(),
            const SizedBox(height: 16),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No garments in ${_selectedCategory.label}',
                        style: AppTextStyle.regular16.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio:
                                AppDimens.garmentCardWidth /
                                AppDimens.garmentCardHeight,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final g = items[i];
                        final selected =
                            g.id != null && _selectedIds.contains(g.id);
                        return GarmentCard(
                          garment: g,
                          isSelected: selected,
                          onTap: () => _toggle(g),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionButton(
        label: 'Confirm',
        onPressed: () => Navigator.pop(context, _selectedIds),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return ColoredBox(
      color: AppColors.surface,
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final category = _categories[i];
            final isSelected = category == _selectedCategory;

            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.nearBlack : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.nearBlack : Colors.black12,
                  ),
                ),
                child: Center(
                  child: Text(
                    category.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.bold16.copyWith(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
