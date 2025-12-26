import 'dart:io';

import 'package:flutter/material.dart';
import 'add_garment_page.dart';
import 'garment_category.dart';
import 'theme/app_colors.dart';

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
      category: GarmentCategory.top,
      imageUrl: 'https://via.placeholder.com/300',
    ),
    Garment(
      id: '2',
      name: 'Jeans',
      category: GarmentCategory.bottom,
      imageUrl: 'https://via.placeholder.com/300',
    ),
  ];

  List<Garment> get _filteredGarments {
    return _allGarments
        .where((g) => g.category == _selectedCategory)
        .toList();
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

                    // 你現在 AddGarmentPage 回傳的是 Map（category/local_path），先兼容一下
                    if (result is Garment) {
                      setState(() {
                        _allGarments.add(result);
                        _selectedCategory = result.category;
                      });
                    } else if (result is Map) {
                      // demo：用 local_path 當成 imageUrl（之後換成 backend image_url）
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
            showCheckmark: true,
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

        // 支援 network / local path（你現在 placeholder + local 都可能出現）
        final bool isLocal = !garment.imageUrl.startsWith('http');

        return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: isLocal
                      ? Image.file(
                    File(garment.imageUrl),
                    fit: BoxFit.cover,
                  )
                      : Image.network(
                    garment.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Text(
                    garment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}