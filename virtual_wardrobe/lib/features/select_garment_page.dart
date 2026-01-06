import 'package:flutter/material.dart';
import 'garment_category.dart';
import '../app/theme/app_colors.dart';

class SelectGarmentPage extends StatelessWidget {
  final String title;
  final GarmentCategory category;
  final List<Garment> items;

  const SelectGarmentPage({
    super.key,
    required this.title,
    required this.category,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((g) => g.category == category).toList();

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
                    child: Image.network(
                      g.uploadUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
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
}