import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/garment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/garment_color_type_filter.dart';
import '../widgets/garment/category_selector.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';

/// Single-garment grid picker; tapping an item pops with it (no confirm).
/// With [categoryTabs] it shows a [CategorySelector]; otherwise it lists
/// [garments] filtered to [category].
class SelectGarmentPage extends StatefulWidget {
  final String title;

  /// Null = no category filter. With [categoryTabs], the tab to open on
  /// (falls back to the first).
  final GarmentCategory? category;

  final List<Garment> garments;
  final Garment? selected;

  final List<GarmentCategory>? categoryTabs;

  const SelectGarmentPage({
    super.key,
    required this.title,
    this.category,
    required this.garments,
    this.selected,
    this.categoryTabs,
  });

  @override
  State<SelectGarmentPage> createState() => _SelectGarmentPageState();
}

class _SelectGarmentPageState extends State<SelectGarmentPage> {
  final _filter = GarmentColorTypeFilter();

  bool get _tabMode =>
      widget.categoryTabs != null && widget.categoryTabs!.isNotEmpty;

  late GarmentCategory _selectedTab = _initialTab();

  GarmentCategory _initialTab() {
    final tabs = widget.categoryTabs;
    if (tabs == null || tabs.isEmpty) return GarmentCategory.top;
    return widget.category != null && tabs.contains(widget.category)
        ? widget.category!
        : tabs.first;
  }

  List<Garment> get _byCategory {
    if (_tabMode) {
      return widget.garments.where((g) => g.category == _selectedTab).toList();
    }
    return widget.category == null
        ? widget.garments
        : widget.garments.where((g) => g.category == widget.category).toList();
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: widget.title,
      actions: [
        _filter.buildButton(
          AppLocalizations.of(context),
          _byCategory,
          onChanged: () => setState(() {}),
        ),
      ],
      bottom: _tabMode
          ? CategorySelector(
              categories: widget.categoryTabs!,
              selectedCategory: _selectedTab,
              onSelected: (category) => setState(() {
                _selectedTab = category;
                _filter.reset();
              }),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final items = _filter.apply(_byCategory);
    return GarmentGrid(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final g = items[i];
        return GarmentCard(
          garment: g,
          // Single pick that pops right away, so a checkbox would mislead.
          showSelectionIndicator: false,
          isSelected:
              widget.selected?.id != null && widget.selected!.id == g.id,
          onTap: () => Navigator.pop(context, SelectGarmentResult(g)),
        );
      },
    );
  }
}
