import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../data/garment.dart';
import '../l10n/generated/app_localizations.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/buttons/filter_button.dart';
import 'widgets/garment/garment_card.dart';

/// Full-page grid picker for a single outfit slot (Top/Bottom/Shoes/etc).
/// Tapping an item — or the "None" tile — immediately pops back with the
/// result; there's no separate confirm step. Mirrors SelectAccessoryPage's
/// design.
class SelectGarmentPage extends StatefulWidget {
  final String title;
  final GarmentCategory category;
  final List<Garment> garments;
  final Garment? selected;

  const SelectGarmentPage({
    super.key,
    required this.title,
    required this.category,
    required this.garments,
    this.selected,
  });

  @override
  State<SelectGarmentPage> createState() => _SelectGarmentPageState();
}

class _SelectGarmentPageState extends State<SelectGarmentPage> {
  Set<String> _selectedColors = {'All'};
  Set<String> _selectedTypes = {'All'};

  List<Garment> get _byCategory =>
      widget.garments.where((g) => g.category == widget.category).toList();

  List<String> get _availableColors {
    final colors =
        _byCategory
            .map((g) => g.color)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...colors];
  }

  List<String> get _availableTypes {
    final types =
        _byCategory
            .map((g) => g.subCategory)
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...types];
  }

  bool get _isFiltered =>
      !_selectedColors.contains('All') || !_selectedTypes.contains('All');

  List<Garment> get _filtered {
    return _byCategory.where((g) {
      final okColor =
          _selectedColors.contains('All') ||
          (g.color != null &&
              _selectedColors.any(
                (c) => c.toLowerCase() == g.color!.toLowerCase(),
              ));
      final okType =
          _selectedTypes.contains('All') ||
          _selectedTypes.any(
            (t) => t.toLowerCase() == g.subCategory.toLowerCase(),
          );
      return okColor && okType;
    }).toList();
  }

  AppToolBar _buildAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: widget.title,
      actions: [
        FilterButton(
          isFiltered: _isFiltered,
          count: _filtered.length,
          groups: [
            FilterGroup(
              label: l10n.color,
              options: _availableColors,
              selected: () => _selectedColors,
              onToggle: (v) => setState(
                () => _selectedColors = FilterButton.toggleWithAll(
                  _selectedColors,
                  v,
                ),
              ),
            ),
            FilterGroup(
              label: l10n.productType,
              options: _availableTypes,
              selected: () => _selectedTypes,
              onToggle: (v) => setState(
                () => _selectedTypes = FilterButton.toggleWithAll(
                  _selectedTypes,
                  v,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _filtered;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: AppDimens.garmentCardHeight,
        ),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _buildNoneCard(context, l10n);
          final g = items[i - 1];
          return GarmentCard(
            garment: g,
            isSelected:
                widget.selected?.id != null && widget.selected!.id == g.id,
            onTap: () => Navigator.pop(context, SelectGarmentResult(g)),
          );
        },
      ),
    );
  }

  Widget _buildNoneCard(BuildContext context, AppLocalizations l10n) {
    final isSelected = widget.selected == null;
    return GestureDetector(
      onTap: () => Navigator.pop(context, const SelectGarmentResult(null)),
      child: SizedBox(
        height: AppDimens.garmentCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pageBackground : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: AppColors.borderStrong, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 32, color: AppColors.icon),
                const SizedBox(height: 8),
                Text(l10n.noneLabel, style: AppTextStyle.bold14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
