import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../data/garment.dart';
import 'widgets/garment_image.dart';
import 'widgets/page_app_bar.dart';

class SelectGarmentPage extends StatelessWidget {
  final String _title;
  final GarmentCategory _category;
  final List<Garment> _garments;

  const SelectGarmentPage({
    super.key,
    required String title,
    required GarmentCategory category,
    required List<Garment> garments,
  }) : _garments = garments, _category = category, _title = title;

  @override
  Widget build(BuildContext context) {
    final filtered = _garments.where((g) => g.category == _category).toList();

    return Scaffold(
      appBar: PageAppBar(title: _title),
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
                  GarmentImage(
                    url: g.imageUrl,
                    width: 64,
                    height: 64,
                    borderRadius: 12,
                    fit: BoxFit.cover,
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

}