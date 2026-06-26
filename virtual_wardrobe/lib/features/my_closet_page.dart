import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../data/garment.dart';
import '../app/theme/app_colors.dart';
import 'widgets/bottom_search_bar.dart';
import 'widgets/garment_upload_helper.dart';
import 'widgets/page_app_bar.dart';
import 'add_garment_page.dart';

class MyClosetPage extends ConsumerStatefulWidget {
  const MyClosetPage({super.key});

  @override
  ConsumerState<MyClosetPage> createState() => _MyClosetPageState();
}

class _MyClosetPageState extends ConsumerState<MyClosetPage> {
  GarmentCategory _selectedCategory = GarmentCategory.top;

  @override
  void initState() {
    super.initState();
    // 監聽 auth 過期，只需在頁面層處理一次
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(garmentsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
    });
  }

  List<Garment> _filtered(List<Garment> all) =>
      all.where((g) => g.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final garmentsAsync = ref.watch(garmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: PageAppBar(
        title: 'My closet',
        backgroundColor: AppColors.defaultToolBar,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/images/plus.png', height: 28),
            ),
            onPressed: () {
              GarmentUploadHelper.showAddClothingDialog(
                context,
                onComplete: () => ref.read(garmentsProvider.notifier).refresh(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
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
          BottomSearchBar(hint: 'Search in "${_selectedCategory.label}"'),
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

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final category = categories[i];
          final isSelected = category == _selectedCategory;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: garments.length,
      itemBuilder: (context, index) => _buildGarmentCard(garments[index]),
    );
  }

  Widget _buildGarmentCard(Garment garment) {
    final img = garment.imageUrl;
    final bool isLocal = img != null && !img.startsWith('http');

    return GestureDetector(
      onTap: () => _editGarment(garment),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: img != null
                      ? (isLocal
                          ? Image.file(File(img), fit: BoxFit.contain)
                          : Image.network(img, fit: BoxFit.contain))
                      : const Center(child: Icon(Icons.image, color: Colors.grey)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bold14.copyWith(color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    garment.color ?? garment.subCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
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
