import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../data/garment.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/filter_button.dart';
import '../widgets/common/cards/favorite_card.dart';
import '../widgets/common/main_nav_bar.dart';
import '../widgets/common/main_tab_async.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/garment/category_selector.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';
import '../widgets/garment/garment_upload_helper.dart';
import 'garment_details_page.dart';

class ClosetPage extends ConsumerStatefulWidget {
  const ClosetPage({super.key});

  @override
  ConsumerState<ClosetPage> createState() => _ClosetPageState();
}

class _ClosetPageState extends ConsumerState<ClosetPage> {
  GarmentCategory _selectedCategory = GarmentCategory.top;
  Set<String> _selectedColors = {'All'};
  Set<String> _selectedProductTypes = {'All'};

  bool get _isFiltered =>
      !_selectedColors.contains('All') ||
      !_selectedProductTypes.contains('All');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final report = mainTabReporter(
        context,
        loadingLabel: AppLocalizations.of(context).loadingClosetEllipsis,
        tab: MainTab.closet,
      );
      report(ref.read(garmentsProvider));
      ref.listenManual(garmentsProvider, (_, next) => report(next));
      ref.read(garmentsProvider.notifier).refreshIfNeeded();
    });
  }

  static const _allCategories = [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outer,
    GarmentCategory.onePiece,
    GarmentCategory.shoes,
    GarmentCategory.socks,
    GarmentCategory.accessory,
  ];

  List<GarmentCategory> _availableCategories(List<Garment> allGarments) =>
      _allCategories
          .where((c) => allGarments.any((g) => g.category == c))
          .toList();

  GarmentCategory _effectiveCategory(List<GarmentCategory> available) {
    if (available.contains(_selectedCategory)) return _selectedCategory;
    return available.isNotEmpty ? available.first : _selectedCategory;
  }

  List<Garment> _filtered(List<Garment> all, GarmentCategory category) {
    return all.where((g) {
      if (g.category != category) return false;
      final okColor =
          _selectedColors.contains('All') ||
          (g.color != null &&
              _selectedColors.any(
                (c) => c.toLowerCase() == g.color!.toLowerCase(),
              ));
      final okType =
          _selectedProductTypes.contains('All') ||
          _selectedProductTypes.contains(g.subCategory);
      return okColor && okType;
    }).toList();
  }

  Widget _buildFilterButton(List<Garment> allGarments) {
    final categoryGarments = allGarments
        .where((g) => g.category == _selectedCategory)
        .toList();
    final availableColors = [
      'All',
      ...GarmentColor.values
          .where(
            (c) => categoryGarments.any(
              (g) =>
                  g.color != null &&
                  g.color!.toLowerCase() == c.label.toLowerCase(),
            ),
          )
          .map((c) => c.label),
    ];
    final availableTypes = [
      'All',
      ...{
        for (final g in categoryGarments)
          if (g.subCategory.isNotEmpty) g.subCategory,
      }.toList()..sort(),
    ];

    final l10n = AppLocalizations.of(context);

    return FilterButton(
      isFiltered: _isFiltered,
      groups: [
        FilterGroup.toggleAll(
          label: l10n.color,
          options: availableColors,
          selected: () => _selectedColors,
          onChanged: (next) => setState(() => _selectedColors = next),
        ),
        FilterGroup.toggleAll(
          label: l10n.productType,
          options: availableTypes,
          selected: () => _selectedProductTypes,
          onChanged: (next) => setState(() => _selectedProductTypes = next),
        ),
      ],
    );
  }

  /// Garments visible in the grid right now — current category with the
  /// color/product-type filters applied.
  int _currentListCount(List<Garment> all) {
    final available = _availableCategories(all);
    final effectiveCategory = _effectiveCategory(available);
    return _filtered(all, effectiveCategory).length;
  }

  AppToolBar _buildAppBar(AsyncValue<List<Garment>> garmentsAsync) {
    final all = garmentsAsync.value ?? [];
    return AppToolBar(
      title: AppLocalizations.of(context).navCloset,
      titleCount: _currentListCount(all),
      centerTitle: false,
      showBackButton: false,
      actions: [_buildFilterButton(all), const SizedBox(width: 8)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final garmentsAsync = ref.watch(garmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(garmentsAsync),
      body: garmentsAsync.mainTabBody(
        data: _buildBody,
        onRetry: () => ref.read(garmentsProvider.notifier).refresh(),
      ),
    );
  }

  Widget _buildBody(List<Garment> all) {
    final available = _availableCategories(all);
    final effectiveCategory = _effectiveCategory(available);
    _scheduleCategoryFix(effectiveCategory);
    return Column(
      children: [
        // Nothing to switch between when the closet is completely empty —
        // skip it so the empty state below centers across the *whole* body
        // instead of a shorter area this 64px-tall bar pushes down by half
        // its height. Still shown whenever at least one category has
        // garments, even if the *currently selected* one doesn't — that's
        // exactly when switching categories matters.
        if (available.isNotEmpty)
          CategorySelector(
            categories: available,
            selectedCategory: effectiveCategory,
            onSelected: (category) => setState(() {
              _selectedCategory = category;
              _selectedColors = {'All'};
              _selectedProductTypes = {'All'};
            }),
          ),
        Expanded(
          child: _buildGarmentGridSection(
            all,
            effectiveCategory,
            closetIsEmpty: available.isEmpty,
          ),
        ),
      ],
    );
  }

  /// If the previously-selected category has no garments left (e.g. after a
  /// delete), the effective category silently falls back to another one —
  /// this syncs `_selectedCategory` to match after the current frame.
  void _scheduleCategoryFix(GarmentCategory effectiveCategory) {
    if (effectiveCategory == _selectedCategory) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _selectedCategory = effectiveCategory);
    });
  }

  Widget _buildGarmentGridSection(
    List<Garment> all,
    GarmentCategory effectiveCategory, {
    required bool closetIsEmpty,
  }) {
    return RefreshIndicator(
      onRefresh: () => ref.read(garmentsProvider.notifier).refresh(),
      color: AppColors.primary,
      child: _buildGrid(
        _filtered(all, effectiveCategory),
        effectiveCategory,
        closetIsEmpty: closetIsEmpty,
      ),
    );
  }

  Widget _buildGrid(
    List<Garment> garments,
    GarmentCategory category, {
    required bool closetIsEmpty,
  }) {
    if (garments.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return EmptyStatePlaceholder(
        icon: Icons.inventory_2_outlined,
        // The whole closet has nothing in it (no category to even name) vs.
        // just this category/filter combo coming up empty while others
        // have stock — same condition [_buildBody] uses to hide
        // CategorySelector.
        title: closetIsEmpty
            ? l10n.noGarmentsInCloset
            : l10n.noGarmentsInCategory(category.localizedLabel(context)),
        message: l10n.closetEmptyCategoryHint,
        actionLabel: l10n.addGarment,
        onAction: _addGarment,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // Dead-centered in the grid's whole Expanded area (not just its own
        // natural size) — same treatment as Trip Suitcase's own empty state.
        fillAvailableSpace: true,
        // Closet is a main tab — MainNavBar floats over the bottom of its
        // Scaffold.body rather than shrinking it (see bottomInset's doc).
        bottomInset: AppDimens.mainNavBarClearance,
      );
    }

    return GarmentGrid(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppDimens.mainNavBarClearance,
      ),
      itemCount: garments.length,
      itemBuilder: (context, index) => _buildGarmentCard(garments[index]),
    );
  }

  /// Triggered by the empty-category state's "Add Garment" CTA — same
  /// dialog the main shell's own quick action opens (see
  /// [main_shell.dart]'s `QuickAction.addClothing`), just without the
  /// tab-switch step since we're already on Closet.
  void _addGarment() {
    GarmentUploadHelper.showAddClothingDialog(
      context,
      onAdded: (g) => ref.read(garmentsProvider.notifier).addGarment(g),
    );
  }

  Widget _buildGarmentCard(Garment garment) {
    return FavoriteCard(
      isFavorite: garment.isFavorite,
      onToggle: () => _toggleFavorite(garment),
      child: GarmentCard(
        garment: garment,
        showSelectionIndicator: false,
        onTap: () => _editGarment(garment),
      ),
    );
  }

  Future<void> _toggleFavorite(Garment garment) async {
    final id = garment.id;
    if (id == null) return;
    final next = !garment.isFavorite;
    ref.read(garmentsProvider.notifier).updateFavorite(id, isFavorite: next);
    try {
      await GarmentService().setFavorite(id, isFavorite: next);
    } on AuthExpiredException {
      ref.read(garmentsProvider.notifier).updateFavorite(id, isFavorite: !next);
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (_) {
      ref.read(garmentsProvider.notifier).updateFavorite(id, isFavorite: !next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToUpdateFavorite),
          ),
        );
      }
    }
  }

  Future<void> _editGarment(Garment garment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentDetailsPage(initialGarment: garment),
      ),
    );

    if (result == 'deleted') {
      ref.read(garmentsProvider.notifier).removeGarment(garment.id!);
      if (mounted) {
        showFeedbackOverlay(
          context,
          message: AppLocalizations.of(context).itemDeleted,
          imagePath: 'assets/images/delete_success.png',
        );
      }
    } else if (result is Garment) {
      ref.read(garmentsProvider.notifier).updateGarment(result);
      if (mounted) {
        showFeedbackOverlay(
          context,
          message: AppLocalizations.of(context).changesSaved,
        );
      }
    }
  }
}
