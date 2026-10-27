import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Page dots plus an "n / total" counter. Renders nothing for one page.
class CarouselDotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;

  const CarouselDotsIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
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
                    color: isActive
                        ? AppColors.textSecondary
                        : AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
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
