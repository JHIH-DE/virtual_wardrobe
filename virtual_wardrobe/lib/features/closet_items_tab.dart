import 'dart:io';

import 'package:flutter/material.dart';
import 'add_garment_page.dart';
import 'garment_category.dart';
import '../app/theme/app_colors.dart';

class ClosetItemsTab extends StatefulWidget {
  const ClosetItemsTab({super.key});

  @override
  State<ClosetItemsTab> createState() => _ClosetItemsTabState();
}

class _ClosetItemsTabState extends State<ClosetItemsTab> {
  GarmentCategory _selectedCategory = GarmentCategory.top;

  // 暫時用假資料，之後換 backend
  final List<Garment> _allGarments = [
    Garment(
      id: '1',
      name: 'White T-Shirt',
      brand: 'Uniqlo',
      color: 'White',
      season: GarmentSeason.all,
      price: 390,
      category: GarmentCategory.top,
      imageUrl: 'https://via.placeholder.com/600',
    ),
    Garment(
      id: '2',
      name: 'Jeans',
      brand: 'Levi\'s',
      color: 'Indigo',
      season: GarmentSeason.autumn,
      price: 2490,
      category: GarmentCategory.bottom,
      imageUrl: 'https://via.placeholder.com/600',
    ),
  ];

  List<Garment> get _filteredGarments {
    return _allGarments.where((g) => g.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddGarmentPage()),
                    );

                    if (result is Garment) {
                      setState(() {
                        _allGarments.add(result);
                        _selectedCategory = result.category;
                      });
                      return;
                    }

                    // backward compatibility: old AddGarmentPage return Map
                    if (result is Map) {
                      final apiValue = result['category'] as String?;
                      final path = result['local_path'] as String?;
                      if (apiValue != null && path != null) {
                        final cat = GarmentCategory.values.firstWhere(
                              (c) => c.apiValue == apiValue,
                          orElse: () => GarmentCategory.top,
                        );
                        setState(() {
                          _allGarments.add(Garment(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: 'New Item',
                            category: cat,
                            imageUrl: path,
                          ));
                          _selectedCategory = cat;
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCategorySelector(),
            const SizedBox(height: 12),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: GarmentCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = GarmentCategory.values[i];
          final isSelected = category == _selectedCategory;

          return ChoiceChip(
            label: Text(
              category.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedCategory = category),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary.withOpacity(0.10),
            side: BorderSide(
              color: isSelected ? AppColors.primary.withOpacity(0.45) : AppColors.border,
              width: isSelected ? 1.2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
            ),
            showCheckmark: false,
            checkmarkColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    if (_filteredGarments.isEmpty) {
      return const Center(
        child: Text(
          'No items in this category',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _filteredGarments.length,
      itemBuilder: (context, index) {
        final garment = _filteredGarments[index];
        final bool isLocal = !garment.imageUrl.startsWith('http');

        return GestureDetector(
          onTap: () => _editGarment(garment),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: isLocal
                            ? Image.file(File(garment.imageUrl), fit: BoxFit.cover)
                            : Image.network(garment.imageUrl, fit: BoxFit.cover),
                      ),
                      _cardFooter(garment),
                    ],
                  ),

                  // actions
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _cardActions(garment),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cardFooter(Garment garment) {
    final subtitleParts = <String>[
      if ((garment.brand ?? '').trim().isNotEmpty) garment.brand!.trim(),
      if ((garment.color ?? '').trim().isNotEmpty) garment.color!.trim(),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            garment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitleParts.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitleParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardActions(Garment garment) {
    Widget actionChip({required IconData icon, required VoidCallback onTap, required String tooltip}) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(99),
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        actionChip(
          icon: Icons.edit,
          tooltip: 'Edit',
          onTap: () => _editGarment(garment),
        ),
        const SizedBox(width: 8),
        actionChip(
          icon: Icons.delete,
          tooltip: 'Delete',
          onTap: () => _deleteGarment(garment),
        ),
      ],
    );
  }

  Future<void> _editGarment(Garment garment) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddGarmentPage(initialGarment: garment)),
    );

    if (updated is! Garment) return;

    setState(() {
      final idx = _allGarments.indexWhere((g) => g.id == garment.id);
      if (idx != -1) {
        _allGarments[idx] = updated;
        _selectedCategory = updated.category;
      }
    });
  }

  Future<void> _deleteGarment(Garment garment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "${garment.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      _allGarments.removeWhere((g) => g.id == garment.id);
    });
  }
}