import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../data/garment.dart';
import 'edit_garment_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/garment/category_selector.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/favorite_card.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/filter_button.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/garment/garment_card.dart';

class MyClosetPage extends ConsumerStatefulWidget {
  const MyClosetPage({super.key});

  @override
  ConsumerState<MyClosetPage> createState() => _MyClosetPageState();
}

class _MyClosetPageState extends ConsumerState<MyClosetPage> {
  GarmentCategory _selectedCategory = GarmentCategory.top;
  final Set<String> _selectedColors = {};
  final Set<String> _selectedProductTypes = {};

  bool get _isFiltered =>
      _selectedColors.isNotEmpty || _selectedProductTypes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(garmentsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
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
          _selectedColors.isEmpty ||
          (g.color != null &&
              _selectedColors.any(
                (c) => c.toLowerCase() == g.color!.toLowerCase(),
              ));
      final okType =
          _selectedProductTypes.isEmpty ||
          _selectedProductTypes.contains(g.subCategory);
      return okColor && okType;
    }).toList();
  }

  Widget _buildFilterButton(List<Garment> allGarments) {
    final categoryGarments = allGarments
        .where((g) => g.category == _selectedCategory)
        .toList();
    final availableColors = GarmentColor.values
        .where(
          (c) => categoryGarments.any(
            (g) =>
                g.color != null &&
                g.color!.toLowerCase() == c.label.toLowerCase(),
          ),
        )
        .toList();
    final availableTypes =
        categoryGarments
            .map((g) => g.subCategory)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return FilterButton(
      isFiltered: _isFiltered,
      groups: [
        FilterGroup(
          label: 'Color',
          options: availableColors.map((c) => c.label).toList(),
          selected: () => _selectedColors,
          emptyMessage: 'No colors available',
          onToggle: (v) => setState(() {
            if (_selectedColors.contains(v)) {
              _selectedColors.remove(v);
            } else {
              _selectedColors.add(v);
            }
          }),
        ),
        FilterGroup(
          label: 'Product Type',
          options: availableTypes,
          selected: () => _selectedProductTypes,
          emptyMessage: 'No types available',
          onToggle: (v) => setState(() {
            if (_selectedProductTypes.contains(v)) {
              _selectedProductTypes.remove(v);
            } else {
              _selectedProductTypes.add(v);
            }
          }),
        ),
      ],
    );
  }

  AppToolBar _buildAppBar(
    BuildContext context,
    AsyncValue<List<Garment>> garmentsAsync,
  ) {
    return AppToolBar(
      title: 'Closet',
      showBackButton: false,
      actions: [
        _buildFilterButton(garmentsAsync.valueOrNull ?? []),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final garmentsAsync = ref.watch(garmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(context, garmentsAsync),
      body: garmentsAsync.when(
        loading: () => const LoadingOverlay(label: 'Loading Closet...'),
        error: (e, _) => ErrorStateWidget(
          error: e,
          onRetry: () => ref.read(garmentsProvider.notifier).refresh(),
        ),
        data: _buildBody,
      ),
    );
  }

  Widget _buildBody(List<Garment> all) {
    final available = _availableCategories(all);
    final effectiveCategory = _effectiveCategory(available);
    _scheduleCategoryFix(effectiveCategory);
    return Column(
      children: [
        CategorySelector(
          categories: available,
          selectedCategory: effectiveCategory,
          onSelected: (category) => setState(() {
            _selectedCategory = category;
            _selectedColors.clear();
            _selectedProductTypes.clear();
          }),
        ),
        Expanded(child: _buildGarmentGridSection(all, effectiveCategory)),
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
    GarmentCategory effectiveCategory,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(garmentsProvider.notifier).refresh(),
      color: AppColors.primary,
      child: _buildGrid(_filtered(all, effectiveCategory), effectiveCategory),
    );
  }

  Widget _buildGrid(List<Garment> garments, GarmentCategory category) {
    if (garments.isEmpty) {
      return ListView(
        children: [
          EmptyStatePlaceholder(
            message: 'No garments in ${category.label}',
            icon: Icons.inventory_2_outlined,
            padding: const EdgeInsets.only(top: 100),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppDimens.floatingNavBarClearance,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: AppDimens.garmentCardHeight,
      ),
      itemCount: garments.length,
      itemBuilder: (context, index) => _buildGarmentCard(garments[index]),
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
    } catch (e) {
      ref.read(garmentsProvider.notifier).updateFavorite(id, isFavorite: !next);
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorite')),
        );
      }
    }
  }

  Future<void> _editGarment(Garment garment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditGarmentPage(initialGarment: garment),
      ),
    );

    if (result == 'deleted') {
      ref.read(garmentsProvider.notifier).removeGarment(garment.id!);
    } else if (result is Garment) {
      ref.read(garmentsProvider.notifier).updateGarment(result);
    }
  }
}
