import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../data/garment.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import 'garment_details_page.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/garment/category_selector.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/cards/favorite_card.dart';
import '../widgets/common/cards/count_pill.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/common/buttons/filter_button.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/garment/garment_card.dart';

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
      _reportLoadingState(ref.read(garmentsProvider));
      ref.listenManual(garmentsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
        _reportLoadingState(next);
      });
      ref.read(garmentsProvider.notifier).refreshIfNeeded();
    });
  }

  /// Mirrors garmentsProvider's loading state up to MainShell, which shows
  /// a full-screen overlay above the floating nav bar — see
  /// MainShellScope.setLoading for why this can't just be built inline.
  void _reportLoadingState(AsyncValue<List<Garment>> state) {
    MainShellScope.of(context)?.setLoading(
      state.isLoading,
      label: AppLocalizations.of(context).loadingClosetEllipsis,
    );
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
        FilterGroup(
          label: l10n.color,
          options: availableColors,
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
          options: availableTypes,
          selected: () => _selectedProductTypes,
          onToggle: (v) => setState(
            () => _selectedProductTypes = FilterButton.toggleWithAll(
              _selectedProductTypes,
              v,
            ),
          ),
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

  AppToolBar _buildAppBar(
    BuildContext context,
    AsyncValue<List<Garment>> garmentsAsync,
  ) {
    final all = garmentsAsync.valueOrNull ?? [];
    return AppToolBar(
      title: AppLocalizations.of(context).navCloset,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context).navCloset,
            textScaler: TextScaler.noScaling,
            style: AppTextStyle.bold18,
          ),
          const SizedBox(width: 8),
          CountPill(count: _currentListCount(all)),
        ],
      ),
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
      appBar: _buildAppBar(context, garmentsAsync),
      body: garmentsAsync.when(
        // The shell-level overlay (via MainShellScope.setLoading, wired up
        // in initState) covers the whole screen including the nav bar, so
        // there's nothing to render here while loading.
        loading: () => const SizedBox.shrink(),
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
            _selectedColors = {'All'};
            _selectedProductTypes = {'All'};
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
            message: AppLocalizations.of(
              context,
            ).noGarmentsInCategory(category.localizedLabel(context)),
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
        crossAxisSpacing: AppDimens.cardSpacing,
        mainAxisSpacing: AppDimens.cardSpacing,
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
