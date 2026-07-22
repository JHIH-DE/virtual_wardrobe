import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/look.dart';

class LookCard extends StatelessWidget {
  final Look look;
  final VoidCallback onTap;

  const LookCard({super.key, required this.look, required this.onTap});

  String get _label {
    if (look.name != null && look.name!.isNotEmpty) return look.name!;
    final parts = [
      ...look.style,
      ...look.seasons,
    ].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Look #${look.id}';
    return parts.map(_capitalize).join(' ');
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Widget _buildImageFallback(IconData icon, String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.icon),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyle.regular12.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.lookCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: AppColors.surface,
                    child: look.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: look.imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (_, __, ___) => _buildImageFallback(
                              Icons.broken_image_outlined,
                              'Failed to Load',
                            ),
                          )
                        : _buildImageFallback(Icons.image_outlined, 'No Image'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bold14.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
