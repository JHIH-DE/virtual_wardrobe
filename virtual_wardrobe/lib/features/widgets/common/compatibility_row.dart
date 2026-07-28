import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../garment/garment_image.dart';

/// A tappable "N Category" row for the AI compatibility card — stacked
/// thumbnail previews plus a trailing chevron make the row read as a door
/// into the closet rather than a line of statistics, so it doesn't need
/// "tap to view" copy to be understood as interactive.
class CompatibilityRow extends StatefulWidget {
  final String label;
  final int count;
  final List<Garment> previewGarments;
  final VoidCallback onTap;

  const CompatibilityRow({
    super.key,
    required this.label,
    required this.count,
    required this.previewGarments,
    required this.onTap,
  });

  @override
  State<CompatibilityRow> createState() => _CompatibilityRowState();
}

class _CompatibilityRowState extends State<CompatibilityRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.accent.withValues(alpha: 0.15),
          highlightColor: AppColors.accent.withValues(alpha: 0.08),
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _ThumbnailStack(garments: widget.previewGarments),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppTextStyle.bold14,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${widget.count}',
                  style: AppTextStyle.bold16.copyWith(color: AppColors.accent),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailStack extends StatelessWidget {
  final List<Garment> garments;

  const _ThumbnailStack({required this.garments});

  static const double _size = 32;
  static const double _overlap = 14;

  @override
  Widget build(BuildContext context) {
    final shown = garments.take(3).toList();
    if (shown.isEmpty) {
      return const SizedBox(
        width: _size,
        height: _size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return SizedBox(
      width: _size + _overlap * (shown.length - 1),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * _overlap,
              child: Container(
                width: _size,
                height: _size,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: GarmentImage(
                  url: shown[i].imageUrl,
                  garmentId: shown[i].id,
                  memCacheWidth: 64,
                  memCacheHeight: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
