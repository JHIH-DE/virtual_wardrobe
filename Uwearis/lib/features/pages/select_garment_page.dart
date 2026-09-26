import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/garment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/garment_color_type_filter.dart';
import '../widgets/garment/category_selector.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';

/// Full-page grid picker for a single outfit slot (Top/Bottom/Shoes/etc) or
/// for an accessory slot. Tapping an item immediately pops back with the
/// result; there's no separate confirm step.
///
/// Two modes:
/// - **Slot mode** (default): the caller passes a single [category] (or null
///   for a pre-filtered candidate list) and the grid shows just that slot's
///   garments.
/// - **Tab mode**: the caller passes [categoryTabs] and the page shows a
///   [CategorySelector] so the user can browse every category and pick any
///   one garment — used by Add Outfit's "Add garment" flow. Still single
///   select, still pops on tap.
class SelectGarmentPage extends StatefulWidget {
  final String title;

  /// The slot's category. Null = don't pre-filter by category (the caller
  /// already passed the exact candidate list — e.g. the Add Outfit accessory
  /// picker, which mixes accessories and socks). In [categoryTabs] mode this
  /// is instead the tab to open on (falls back to the first tab).
  final GarmentCategory? category;

  final List<Garment> garments;
  final Garment? selected;

  /// When non-null, the page runs in tab mode: a [CategorySelector] over
  /// these categories replaces the fixed [category] filter, letting the user
  /// pick any garment from any category in one visit.
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabMode) {
      return Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            CategorySelector(
              categories: widget.categoryTabs!,
              selectedCategory: _selectedTab,
              onSelected: (category) => setState(() {
                _selectedTab = category;
                _filter.reset();
              }),
            ),
            Expanded(child: _buildGrid()),
          ],
        ),
      );
    }
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
          isSelected:
              widget.selected?.id != null && widget.selected!.id == g.id,
          onTap: () => Navigator.pop(context, SelectGarmentResult(g)),
        );
      },
    );
  }
}
