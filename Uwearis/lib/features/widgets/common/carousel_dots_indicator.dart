import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

enum CarouselDotsVariant {
  /// Grey dots plus an "n / total" counter, below a carousel.
  onPage,

  /// White dots only, laid over the carousel's photo.
  onPhoto,
}

/// Page dots for a carousel. Renders nothing for one page.
class CarouselDotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final CarouselDotsVariant variant;

  const CarouselDotsIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.variant = CarouselDotsVariant.onPage,
  });

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final onPhoto = variant == CarouselDotsVariant.onPhoto;
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(count, (index) {
                final isActive = index == currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: switch ((onPhoto, isActive)) {
                      (true, true) => AppColors.textOnPrimary,
                      (true, false) => AppColors.onPhotoMuted,
                      (false, true) => AppColors.textSecondary,
                      (false, false) => AppColors.borderSubtle,
                    },
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          if (!onPhoto)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${currentIndex + 1} / $count',
                style: AppTextStyle.semibold14.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
