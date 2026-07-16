import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Photo preview when [imageProvider] is set, otherwise a dashed-border
/// "Upload Image" placeholder with a choose-photo button.
class PhotoUploadField extends StatelessWidget {
  final ImageProvider? imageProvider;
  final VoidCallback? onTap;
  final double aspectRatio;
  final String title;
  final String subtitle;
  final String buttonLabel;

  const PhotoUploadField({
    super.key,
    required this.imageProvider,
    required this.onTap,
    this.aspectRatio = 3 / 4,
    this.title = 'Upload Image',
    this.subtitle = 'Please choose a clear photo.',
    this.buttonLabel = 'Choose photo',
  });

  @override
  Widget build(BuildContext context) {
    final provider = imageProvider;
    if (provider != null) {
      return Center(
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Image(image: provider, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.borderStrong,
          radius: 16,
        ),
        child: Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            color: AppColors.placeholderSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: AppTextStyle.semibold16),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTextStyle.regular13.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.upload, size: 16),
                label: Text(buttonLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.textPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const sw = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sw / 2, sw / 2, size.width - sw, size.height - sw),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segmentEnd = (distance + (draw ? 8.0 : 5.0)).clamp(
          0.0,
          metric.length,
        );
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, segmentEnd), paint);
        }
        distance = segmentEnd;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
