import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/trip_suggestion_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/packing_analysis.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/garment_color_type_filter.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/expandable_insight_body.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/garment/category_selector.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';
import 'trip_outfit_selection_page.dart';

class TripGarmentSelectionPage extends ConsumerStatefulWidget {
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
  ConsumerState<TripGarmentSelectionPage> createState() =>
      _TripGarmentSelectionPageState();
}

class _TripGarmentSelectionPageState
    extends ConsumerState<TripGarmentSelectionPage> {
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

  /// This page is a pure picker now — it always hands the current selection
  /// back to [TripSuitcasePage], which stages the diff and shows its own
  /// "Confirm" button.
  void _returnSelection() => Navigator.pop(context, _selectedIds);

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    try {
      // Same analysis Trip Details already fetched (see tripSuggestionProvider).
      final analysis = await ref.read(
        tripSuggestionProvider(widget.tripId).future,
      );
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
      onBack: _returnSelection,
      actions: [
        IconButton(
          // Zero padding + a toolbar-slot square so the hit target matches
          // the back button / "⋮" menu (see FilterButton).
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: AppDimens.toolbarHeight,
            minHeight: AppDimens.toolbarHeight,
          ),
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

  /// Orders a category's grid: items selected *on entry* first, then
  /// AI-suggested, then everything else — each bucket keeps the closet's own
  /// order. Keyed off [TripGarmentSelectionPage.initiallySelectedIds] rather
  /// than the live selection on purpose: toggling an item during this visit
  /// must not make it jump buckets under the user's finger. The order only
  /// re-settles next time the page is opened.
  List<Garment> _sortedItemsForCategory(PackingCategory? advice) {
    final items = _filter.apply(_byCategory);
    final suggested = advice?.suggestedGarmentIds ?? const <int>{};
    final selectedBucket = <Garment>[];
    final suggestedBucket = <Garment>[];
    final restBucket = <Garment>[];
    for (final g in items) {
      if (widget.initiallySelectedIds.contains(g.id)) {
        selectedBucket.add(g);
      } else if (suggested.contains(g.id)) {
        suggestedBucket.add(g);
      } else {
        restBucket.add(g);
      }
    }
    return [...selectedBucket, ...suggestedBucket, ...restBucket];
  }

  @override
  Widget build(BuildContext context) {
    final advice = _adviceByCategory[_selectedCategory];
    final items = _sortedItemsForCategory(advice);
    final selectedInCategory = _byCategory
        .where((g) => _selectedIds.contains(g.id))
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnSelection();
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildCategorySelector(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (_loadingAdvice || advice != null)
                    SliverToBoxAdapter(
                      child: _buildUwearisInsightCard(
                        advice,
                        selectedInCategory,
                      ),
                    ),
                  _buildGridSliver(items, advice),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
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
