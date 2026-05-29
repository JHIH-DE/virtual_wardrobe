import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/config/app_text_style.dart';
import '../core/services/error_handler.dart';
import '../core/services/garments_service.dart';
import '../data/garment_category.dart';
import 'widgets/garment_upload_helper.dart';
import 'add_garment_page.dart';

class MyClosetPage extends StatefulWidget {
  const MyClosetPage({super.key});

  @override
  State<MyClosetPage> createState() => _MyClosetPageState();
}

class _MyClosetPageState extends State<MyClosetPage> {
  final List<Garment> _allGarments = [];

  GarmentCategory _selectedCategory = GarmentCategory.top;
  bool _loading = false;
  String? _error;

  List<Garment> get _filteredGarments =>
      _allGarments.where((g) => g.category == _selectedCategory).toList();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await GarmentService().getGarments();
      if (!mounted) return;
      setState(() {
        _allGarments
          ..clear()
          ..addAll(list);
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color pageBgColor = Color(0xFFF5F2EE); // 定義統一背景色

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: pageBgColor, // 不要用 transparent，改用跟背景一樣的顏色
        surfaceTintColor: Colors.transparent, // 防止捲動時變色
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/page-arrow.png',
              height: 28,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My closet',
          textScaler: TextScaler.noScaling,
          style: AppTextStyle.bold16,
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/images/plus.png',
                height: 28,
              ),
            ),
            onPressed: () {
              GarmentUploadHelper.showAddClothingDialog(
                context,
                onComplete: _refresh,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
              _buildCategorySelector(),
              const SizedBox(height: 16),
              if (_loading && _allGarments.isEmpty)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: Colors.black,
                    child: _buildGrid(),
                  ),
                ),
            ],
          ),
          _buildBottomSearchBar(),
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

  Widget _buildGrid() {
    if (!_loading && _filteredGarments.isEmpty) {
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), // 增加底部間距以防遮擋
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75),
      itemCount: _filteredGarments.length,
      itemBuilder: (context, index) {
        final garment = _filteredGarments[index];
        return _buildGarmentCard(garment);
      },
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    garment.color ?? garment.subCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSearchBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25), // 灰階遮罩背景
        ),
        child: Center(
          child: Container(
            width: 335,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.only(left: 24, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Search in "${_selectedCategory.label}"',
                    style: AppTextStyle.bold16.copyWith(
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                // 右側搜尋圖示與方框
                Container(
                  padding: const EdgeInsets.all(6),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Image.asset(
                      'assets/images/search.png',
                      height: 28,
                    ),
                    onPressed: () {
                      // 這裡可以加入搜尋邏輯
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editGarment(Garment garment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddGarmentPage(initialGarment: garment)),
    );

    if (result == 'deleted' || result is Garment) {
      _refresh();
    }
  }
}
