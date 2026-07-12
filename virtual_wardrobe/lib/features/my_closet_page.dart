import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../data/garment.dart';
import 'add_garment_page.dart';
import 'widgets/common/category_selector.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/filter_icon_button.dart';
import 'widgets/common/filter_sheet_scaffold.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/common/selectable_chip.dart';
import 'widgets/garment/garment_card.dart';
import 'widgets/garment/garment_upload_helper.dart';

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

  void _openFilterSheet(List<Garment> allGarments) {
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

    showAppFilterSheet(
      context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return FilterSheetContent(
            children: [
              Text('Color', style: AppTextStyle.bold16),
              const SizedBox(height: 10),
              availableColors.isEmpty
                  ? Text(
                      'No colors available',
                      style: AppTextStyle.regular14.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableColors.map((c) {
                        final selected = _selectedColors.contains(
                          c.label.toLowerCase(),
                        );
                        return SelectableChip(
                          label: c.label,
                          selected: selected,
                          onTap: () {
                            setSheetState(() {});
                            setState(() {
                              if (selected) {
                                _selectedColors.remove(c.label.toLowerCase());
                              } else {
                                _selectedColors.add(c.label.toLowerCase());
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 20),
              Text('Product Type', style: AppTextStyle.bold16),
              const SizedBox(height: 10),
              availableTypes.isEmpty
                  ? Text(
                      'No types available',
                      style: AppTextStyle.regular14.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTypes.map((t) {
                        final selected = _selectedProductTypes.contains(t);
                        return SelectableChip(
                          label: t,
                          selected: selected,
                          onTap: () {
                            setSheetState(() {});
                            setState(() {
                              if (selected) {
                                _selectedProductTypes.remove(t);
                              } else {
                                _selectedProductTypes.add(t);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final garmentsAsync = ref.watch(garmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: PageAppBar(
        title: 'My closet',
        backgroundColor: AppColors.defaultToolBar,
        onBack: () => Navigator.popUntil(context, (route) => route.isFirst),
        actions: [
          FilterIconButton(
            isFiltered: _isFiltered,
            onPressed: () => _openFilterSheet(garmentsAsync.valueOrNull ?? []),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/images/plus.png',
                height: AppDimens.iconMediumSize,
              ),
            ),
            onPressed: () {
              GarmentUploadHelper.showAddClothingDialog(
                context,
                onAdded: (g) =>
                    ref.read(garmentsProvider.notifier).addGarment(g),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: garmentsAsync.when(
          loading: () => const LoadingOverlay(label: 'Loading Closet...'),
          error: (e, _) => ErrorStateWidget(
            error: e,
            onRetry: () => ref.read(garmentsProvider.notifier).refresh(),
          ),
          data: (all) {
            final available = _availableCategories(all);
            final effectiveCategory = _effectiveCategory(available);
            if (effectiveCategory != _selectedCategory) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedCategory = effectiveCategory);
                }
              });
            }
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
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.read(garmentsProvider.notifier).refresh(),
                    color: Colors.black,
                    child: _buildGrid(
                      _filtered(all, effectiveCategory),
                      effectiveCategory,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio:
            AppDimens.garmentCardWidth / AppDimens.garmentCardHeight,
      ),
      itemCount: garments.length,
      itemBuilder: (context, index) => GarmentCard(
        garment: garments[index],
        showSelectionIndicator: false,
        onTap: () => _editGarment(garments[index]),
      ),
    );
  }

  Future<void> _editGarment(Garment garment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddGarmentPage(initialGarment: garment),
      ),
    );

    if (result == 'deleted') {
      ref.read(garmentsProvider.notifier).removeGarment(garment.id!);
    } else if (result is Garment) {
      ref.read(garmentsProvider.notifier).updateGarment(result);
    }
  }
}
