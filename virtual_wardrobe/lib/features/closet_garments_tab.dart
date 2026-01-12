import 'dart:io';

import 'package:flutter/material.dart';
import 'add_garment_page.dart';
import 'garment_category.dart';
import '../app/theme/app_colors.dart';
import '../core/services/auth_api.dart';
import '../core/services/token_storage.dart';

class ClosetGarmentsTab extends StatefulWidget {
  const ClosetGarmentsTab({super.key});

  @override
  State<ClosetGarmentsTab> createState() => _ClosetGarmentsTabState();
}

class _ClosetGarmentsTabState extends State<ClosetGarmentsTab> {
  GarmentCategory _selectedCategory = GarmentCategory.top;

  final List<Garment> _allGarments = [];

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
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Missing access token. Please login again.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await AuthApi.getGarments(token);
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
                    'Your Garments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _createGarment,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Garments'),
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

            if (_loading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
              const SizedBox(height: 12),
            ],

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _buildGrid(),
              ),
            ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
            showCheckmark: false, // ✅ 不要勾勾
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    if (!_loading && _filteredGarments.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          Center(
            child: Text(
              'No garments in this category',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
        final img = garment.imageUrl;
        final bool isLocal = !img!.startsWith('http');

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
                            ? Image.file(File(img), fit: BoxFit.cover)
                            : Image.network(img, fit: BoxFit.cover),
                      ),
                      _cardFooter(garment),
                    ],
                  ),
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
    Widget actionChip({
      required IconData icon,
      required VoidCallback onTap,
      required String tooltip,
    }) {
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
        actionChip(icon: Icons.edit, tooltip: 'Edit', onTap: () => _editGarment(garment)),
        const SizedBox(width: 8),
        actionChip(icon: Icons.delete, tooltip: 'Delete', onTap: () => _deleteGarment(garment)),
      ],
    );
  }

  Future<void> _createGarment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddGarmentPage()),
    );

    if (result is! Garment) return;

    setState(() {
      _allGarments.add(result);
      _selectedCategory = result.category;
    });
  }

  Future<void> _editGarment(Garment garment) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddGarmentPage(initialGarment: garment)),
    );

    if (updated is! Garment) return;

    // 如果你希望「編輯」也同步到後端，就把下面這段打開（需後端 PATCH 支援）
    /*
    final token = TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        final serverUpdated = await AuthApi.updateGarment(token, updated);
        updated = serverUpdated;
      } catch (_) {}
    }
    */

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
        title: const Text('Delete garment?'),
        content: Text('Delete "${garment.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing access token. Please login again.')),
      );
      return;
    }

    try {
      if (garment.id == null) {
        throw Exception('Missing item.id');
      }
      await AuthApi.deleteGarment(token, garment.id!);

      if (!mounted) return;
      setState(() {
        _allGarments.removeWhere((g) => g.id == garment.id);
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}