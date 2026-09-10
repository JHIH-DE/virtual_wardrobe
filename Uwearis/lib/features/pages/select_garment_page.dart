import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/garment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/garment_color_type_filter.dart';
import '../widgets/garment/category_selector.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';
import '../widgets/garment/none_garment_card.dart';

/// Full-page grid picker for a single outfit slot (Top/Bottom/Shoes/etc) or
/// for an accessory slot. Tapping an item — or the "None" tile — immediately
/// pops back with the result; there's no separate confirm step.
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

  /// Whether the "None" tile (clear this slot) shows in the grid — only
  /// makes sense for optional slots (e.g. Mid Layer, Outerwear, accessories);
  /// required slots are cleared via the slot card's own "x" affordance
  /// instead. Ignored in [categoryTabs] mode.
  final bool showNoneOption;

  /// Match a Look's AI ranking for this slot, #1 first — up to 4 ids.
  /// #1 never gets a badge here (it's already the auto-filled selection,
  /// shown via the normal selected checkmark instead); #2-#4 get a small
  /// "✦ #N" marker so the user can still see the AI's other suggestions
  /// without being limited to them.
  final List<int> rankedGarmentIds;

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
    this.showNoneOption = false,
    this.rankedGarmentIds = const [],
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
    final l10n = AppLocalizations.of(context);
    final items = _filter.apply(_byCategory);
    final showNone = widget.showNoneOption && !_tabMode;
    return GarmentGrid(
      itemCount: items.length + (showNone ? 1 : 0),
      itemBuilder: (context, i) {
        if (showNone && i == 0) {
          return NoneGarmentCard(
            isSelected: widget.selected == null,
            label: l10n.noneLabel,
            onTap: () =>
                Navigator.pop(context, const SelectGarmentResult(null)),
          );
        }
        final g = items[showNone ? i - 1 : i];
        final rank = g.id == null ? -1 : widget.rankedGarmentIds.indexOf(g.id!);
        return Stack(
          children: [
            GarmentCard(
              garment: g,
              isSelected:
                  widget.selected?.id != null && widget.selected!.id == g.id,
              onTap: () => Navigator.pop(context, SelectGarmentResult(g)),
            ),
            // rank 0 is AI's #1 pick — already reflected by the normal
            // selected checkmark above, so it doesn't also get a badge.
            if (rank > 0) _buildAiRankBadge(rank + 1),
          ],
        );
      },
    );
  }

  Widget _buildAiRankBadge(int rank) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 10, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              '#$rank',
              style: AppTextStyle.bold12.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
