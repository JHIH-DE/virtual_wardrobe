import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/packing_analysis.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/buttons/garment_color_type_filter.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/expandable_insight_body.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/garment/category_selector.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';
import 'trip_outfit_selection_page.dart';

class TripGarmentSelectionPage extends StatefulWidget {
  final int tripId;
  final List<Garment> garments;
  final Set<int> initiallySelectedIds;

  const TripGarmentSelectionPage({
    super.key,
    required this.tripId,
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
  late final List<GarmentCategory> _availableCategories = _categories
      .where((c) => widget.garments.any((g) => g.category == c))
      .toList();
  late GarmentCategory _selectedCategory = _availableCategories.isEmpty
      ? GarmentCategory.top
      : _availableCategories.first;
  final Map<GarmentCategory, PackingCategory> _adviceByCategory = {};
  bool _loadingAdvice = true;
  bool _reasoningExpanded = false;

  final _filter = GarmentColorTypeFilter();

  bool get _isModified => !setEquals(_selectedIds, widget.initiallySelectedIds);

  bool get _showsBottomActionButton => _isModified;

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    try {
      final analysis = await TripService().getTripSuggestion(widget.tripId);
      _adviceByCategory
        ..clear()
        ..addEntries(analysis.categories.map((c) => MapEntry(c.category, c)));
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to load packing advice: $e');
    } finally {
      if (mounted) setState(() => _loadingAdvice = false);
    }
  }

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

  /// Lets the user pick a saved outfit, then selects whichever of its
  /// garments are still in the current closet, the same way tapping each
  /// one individually would.
  Future<void> _pickFromOutfit() async {
    final outfit = await Navigator.push<Outfit>(
      context,
      MaterialPageRoute(builder: (_) => const TripOutfitSelectionPage()),
    );
    if (outfit == null || !mounted) return;

    final availableIds = widget.garments
        .map((g) => g.id)
        .whereType<int>()
        .toSet();
    final matchedIds = outfit.garmentIds.where(availableIds.contains).toSet();
    final newIds = matchedIds.difference(_selectedIds);

    final l10n = AppLocalizations.of(context);
    if (newIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noNewItemsFromOutfit)));
      return;
    }

    setState(() => _selectedIds.addAll(newIds));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.addedItemsFromOutfitCount(newIds.length))),
    );
  }

  List<Garment> get _byCategory =>
      widget.garments.where((g) => g.category == _selectedCategory).toList();

  AppToolBar _buildAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.selectGarmentsTitle,
      actions: [
        IconButton(
          tooltip: l10n.addFromOutfit,
          icon: const Icon(Icons.style_outlined, color: AppColors.icon),
          onPressed: _pickFromOutfit,
        ),
        _filter.buildButton(
          l10n,
          _byCategory,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  /// Suggested garments (per the AI packing advice) sort to the front of
  /// their category's grid.
  List<Garment> _sortedItemsForCategory(PackingCategory? advice) {
    final items = _filter.apply(_byCategory);
    if (advice == null) return items;
    items.sort((a, b) {
      final aSuggested = advice.suggestedGarmentIds.contains(a.id) ? 0 : 1;
      final bSuggested = advice.suggestedGarmentIds.contains(b.id) ? 0 : 1;
      return aSuggested.compareTo(bSuggested);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final advice = _adviceByCategory[_selectedCategory];
    final items = _sortedItemsForCategory(advice);
    final selectedInCategory = _byCategory
        .where((g) => _selectedIds.contains(g.id))
        .length;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildCategorySelector(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (_loadingAdvice || advice != null)
                  SliverToBoxAdapter(
                    child: _buildUwearisInsightCard(advice, selectedInCategory),
                  ),
                _buildGridSliver(items, advice),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionButton(
        label: AppLocalizations.of(context).confirm,
        onPressed: () => Navigator.pop(context, _selectedIds),
        enabled: _isModified,
      ),
    );
  }

  Widget _buildCategorySelector() {
    return CategorySelector(
      categories: _availableCategories,
      selectedCategory: _selectedCategory,
      onSelected: (category) => setState(() {
        _selectedCategory = category;
        _filter.reset();
        _reasoningExpanded = false;
      }),
    );
  }

  Widget _buildGridSliver(List<Garment> items, PackingCategory? advice) {
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStatePlaceholder(
          message: AppLocalizations.of(
            context,
          ).noGarmentsInCategory(_selectedCategory.localizedLabel(context)),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        _showsBottomActionButton ? AppDimens.bottomActionBtnClearance : 16,
      ),
      sliver: SliverGrid(
        gridDelegate: GarmentGrid.gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, i) => _buildGarmentGridItem(items[i], advice),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildGarmentGridItem(Garment g, PackingCategory? advice) {
    final selected = _selectedIds.contains(g.id);
    final suggested = advice?.suggestedGarmentIds.contains(g.id) ?? false;
    return Stack(
      children: [
        GarmentCard(garment: g, isSelected: selected, onTap: () => _toggle(g)),
        if (suggested) _buildSuggestedBadge(advice),
      ],
    );
  }

  Widget _buildSuggestedBadge(PackingCategory? advice) {
    return Positioned(
      top: 8,
      left: 8,
      child: GestureDetector(
        onTap: () {
          final snackBar = SnackBar(
            content: Text(
              advice?.reasoning ?? AppLocalizations.of(context).suggestedByAi,
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        },
        child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.icon),
      ),
    );
  }

  Widget _buildUwearisInsightCard(
    PackingCategory? advice,
    int selectedInCategory,
  ) {
    return UwearisInsightCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _loadingAdvice
          ? Text(
              AppLocalizations.of(context).loadingPackingSuggestions,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          : _buildAdviceContent(advice!, selectedInCategory),
    );
  }

  Widget _buildAdviceContent(PackingCategory advice, int selectedInCategory) {
    return ExpandableInsightBody(
      title: Text(
        AppLocalizations.of(context).recommendedSelectedCount(
          advice.recommendedQuantity,
          selectedInCategory,
        ),
        style: AppTextStyle.regular16,
      ),
      detail: advice.reasoning,
      showToggle: advice.reasoning.isNotEmpty,
      expanded: _reasoningExpanded,
      onToggle: () => setState(() => _reasoningExpanded = !_reasoningExpanded),
    );
  }
}
