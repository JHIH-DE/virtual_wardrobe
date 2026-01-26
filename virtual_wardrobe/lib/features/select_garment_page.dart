import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../data/garment_category.dart';

class SelectGarmentPage extends StatelessWidget {
  final String title;
  final GarmentCategory category;
  final List<Garment> garments;

  const SelectGarmentPage({
    super.key,
    required this.title,
    required this.category,
    required this.garments,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = garments.where((g) => g.category == category).toList();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final g = filtered[i];
          return InkWell(
            onTap: () => Navigator.pop(context, g),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _garmentImage(
                        g.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _garmentImage(String? url,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    final u = (url ?? '').trim();

    if (u.isEmpty) {
      return const Center(child: Text('No image'));
    }

    if (u.startsWith('http://') || u.startsWith('https://')) {
      return Image.network(
        u,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
        const Center(child: Text('Image load failed')),
      );
    }

    if (u.startsWith('file://')) {
      return Image.file(
        File.fromUri(Uri.parse(u)),
        width: width,
        height: height,
        fit: fit,
      );
    }

    return Image.file(
      File(u),
      width: width,
      height: height,
      fit: fit,
    );
  }
}