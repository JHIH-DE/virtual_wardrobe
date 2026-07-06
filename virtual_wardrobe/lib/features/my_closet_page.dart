import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../data/garment.dart';
import 'add_garment_page.dart';
import 'widgets/garment_card.dart';
import 'widgets/garment_upload_helper.dart';
import 'widgets/page_app_bar.dart';

class MyClosetPage extends ConsumerStatefulWidget {
  const MyClosetPage({super.key});

  @override
  ConsumerState<MyClosetPage> createState() => _MyClosetPageState();
}

class _MyClosetPageState extends ConsumerState<MyClosetPage> {
  GarmentCategory _selectedCategory = GarmentCategory.top;
  final Set<String> _selectedColors = {};
  final Set<String> _selectedProductTypes = {};

  bool get _isFiltered => _selectedColors.isNotEmpty || _selectedProductTypes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(garmentsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
    });
  }

  List<Garment> _filtered(List<Garment> all) {
    return all.where((g) {
      if (g.category != _selectedCategory) return false;
      final okColor = _selectedColors.isEmpty ||
          (g.color != null &&
              _selectedColors.any((c) => c.toLowerCase() == g.color!.toLowerCase()));
      final okType = _selectedProductTypes.isEmpty ||
          _selectedProductTypes.contains(g.subCategory);
      return okColor && okType;
    }).toList();
  }

  void _openFilterSheet(List<Garment> allGarments) {
    final categoryGarments = allGarments.where((g) => g.category == _selectedCategory).toList();
    final availableColors = GarmentColor.values
        .where((c) => categoryGarments.any((g) =>
            g.color != null && g.color!.toLowerCase() == c.label.toLowerCase()))
        .toList();
    final availableTypes = categoryGarments
        .map((g) => g.subCategory)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Color', style: AppTextStyle.bold16),
                const SizedBox(height: 10),
                availableColors.isEmpty
                    ? Text('No colors available', style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableColors.map((c) {
                          final selected = _selectedColors.contains(c.label.toLowerCase());
                          return GestureDetector(
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: Text(
                                c.label,
                                style: AppTextStyle.semibold14.copyWith(
                                  color: selected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 20),
                Text('Product Type', style: AppTextStyle.bold16),
                const SizedBox(height: 10),
                availableTypes.isEmpty
                    ? Text('No types available', style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableTypes.map((t) {
                          final selected = _selectedProductTypes.contains(t);
                          return GestureDetector(
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: Text(
                                t,
                                style: AppTextStyle.semibold14.copyWith(
                                  color: selected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ],
            ),
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _openFilterSheet(
                  garmentsAsync.valueOrNull ?? [],
                ),
              ),
              if (_isFiltered)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/images/plus.png', height: AppDimens.iconMediumSize),
            ),
            onPressed: () {
              GarmentUploadHelper.showAddClothingDialog(
                context,
                onAdded: (g) => ref.read(garmentsProvider.notifier).addGarment(g),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildCategorySelector(),
            const SizedBox(height: 16),
            Expanded(
              child: garmentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(e),
                data: (all) => RefreshIndicator(
                  onRefresh: () => ref.read(garmentsProvider.notifier).refresh(),
                  color: Colors.black,
                  child: _buildGrid(_filtered(all)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    if (e is AuthExpiredException) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(e.toString(), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.read(garmentsProvider.notifier).refresh(),
            child: const Text('重試'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      GarmentCategory.top,
      GarmentCategory.bottom,
      GarmentCategory.outer,
      GarmentCategory.shoes,
      GarmentCategory.accessory,
    ];

    return ColoredBox(
      color: AppColors.surface,
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final category = categories[i];
            final isSelected = category == _selectedCategory;

            return GestureDetector(
              onTap: () => setState(() {
                _selectedCategory = category;
                _selectedColors.clear();
                _selectedProductTypes.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1A1A1A) : Colors.black12,
                  ),
                ),
                child: Center(
                  child: Text(
                    category.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.bold16.copyWith(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrid(List<Garment> garments) {
    if (garments.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No garments in ${_selectedCategory.label}',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
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
        childAspectRatio: AppDimens.garmentCardWidth / AppDimens.garmentCardHeight,
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
      MaterialPageRoute(builder: (_) => AddGarmentPage(initialGarment: garment)),
    );

    if (result == 'deleted') {
      ref.read(garmentsProvider.notifier).removeGarment(garment.id!);
    } else if (result is Garment) {
      ref.read(garmentsProvider.notifier).updateGarment(result);
    }
  }
}
