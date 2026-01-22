import 'dart:io';

import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../data/looks_store.dart';
import 'garment_category.dart';

class ClosetLooksTab extends StatefulWidget {
  const ClosetLooksTab({super.key});

  @override
  State<ClosetLooksTab> createState() => _ClosetLooksTabState();
}

class _ClosetLooksTabState extends State<ClosetLooksTab> {
  static const List<String> seasons = [
    'All',
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];
  static const List<String> styles = [
    'All',
    'Minimal',
    'Street',
    'Classic',
    'Sporty'
  ];

  String selectedSeasons = 'All';
  String selectedStyle = 'All';

  List<Look> get _filteredLooks {
    final all = LooksStore.I.looks;
    return all.where((l) {
      final okSeasons = selectedSeasons == 'All' ||
          l.seasons == selectedSeasons;
      final okStyle = selectedStyle == 'All' || l.style == selectedStyle;
      return okSeasons && okStyle;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: LooksStore.I,
        builder: (context, _) {
          final looks = _filteredLooks;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                title: 'Filters',
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedSeasons,
                        items: seasons
                            .map((v) =>
                            DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() =>
                            selectedSeasons = v ?? selectedSeasons),
                        decoration: _inputDecoration(label: 'Seasons'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStyle,
                        items: styles
                            .map((v) =>
                            DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedStyle = v ?? selectedStyle),
                        decoration: _inputDecoration(label: 'Style'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: looks.isEmpty
                    ? const Center(
                  child: Text(
                    'No looks yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
                    : GridView.builder(
                  padding: const EdgeInsets.only(top: 4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72, // 3/4 圖 + label
                  ),
                  itemCount: looks.length,
                  itemBuilder: (context, index) {
                    final look = looks[index];
                    return _lookCard(context, look);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _lookCard(BuildContext context, Look look) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _lookDetailSheet(look),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // 卡片背景改為白色
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: Colors.white, // 圖片背景白色
                      child: Image.network(
                        look.imageUrl,
                        fit: BoxFit.contain, // 改為 contain 避免裁切
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stack) {
                          return const Center(
                            child: Text(
                              'Failed to load image',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),

                    // 右上角刪除
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => _confirmDelete(context, look),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white, // 底部也改為白色
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${look.seasons} • ${look.style}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 18,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lookDetailSheet(Look look) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 全畫面圖片 + 疊加指示條
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 0.65, // 更長的比例，佔據更多畫面
                      child: Image.network(
                        look.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // 疊加在圖片上的指示條
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${look.seasons} • ${look.style}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: look.items.map((garment) {
                            return _buildSmallGarmentItem(garment.category.label, garment);
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                LooksStore.I.removeById(look.id);
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                              ),
                              child: const Text('Remove'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Look look) async {
    debugPrint('Opening Look Detail. ID: ${look.id}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Remove look?',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'This look will be removed from your Looks.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (ok == true) {
      LooksStore.I.removeById(look.id);
    }
  }

  Widget _buildSmallGarmentItem(String label, Garment garment) {
    final String imageUrl = (garment.imageUrl != null && garment.imageUrl!.isNotEmpty)
        ? garment.imageUrl!
        : garment.uploadUrl;

    final bool isNetwork = imageUrl.startsWith('http');

    debugPrint('Building Item: ${garment.name}');

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: isNetwork
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                // 對於 Google Cloud Storage 網址，有時需要忽略快取或特定的連線設定
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Network Image Error: $error');
                  return const Center(
                    child: Icon(Icons.broken_image, size: 20, color: AppColors.textSecondary),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
                  : Image.file(
                File(imageUrl),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, size: 20, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Text(
              garment.name, // 建議顯示衣服名稱，讓使用者更容易對照
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
