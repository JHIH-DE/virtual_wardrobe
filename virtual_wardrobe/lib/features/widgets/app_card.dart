import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

const _kCardShadow = [
  BoxShadow(
    color: Color(0xFFDDDDDD),
    offset: Offset(0, 2),
    blurRadius: 0,
  ),
  BoxShadow(
    color: Color(0xFFCCCCCC),
    offset: Offset(0, 4),
    blurRadius: 0,
  ),
];

BoxShadow _softDropShadow() => BoxShadow(
      color: Colors.black.withOpacity(0.18),
      offset: const Offset(0, 10),
      blurRadius: 20,
      spreadRadius: 0,
    );

/// 方形功能卡片（用於 GridView）
class AppVerticalCard extends StatelessWidget {
  const AppVerticalCard({
    super.key,
    required this.label,
    required this.iconPath,
    required this.isSelected,
    required this.onTap,
    this.height,
  });

  final String label;
  final String iconPath;
  final bool isSelected;
  final VoidCallback onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedScale(
        scale: isSelected ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          decoration: BoxDecoration(
            color: AppColors.defaultCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              ..._kCardShadow,
              _softDropShadow(),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                iconPath,
                height: 80,
                width: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyle.bold18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 橫幅動作卡片（用於 Quick Add 等）
class AppHorizontalCard extends StatelessWidget {
  const AppHorizontalCard({
    super.key,
    required this.label,
    required this.iconPath,
    required this.onTap,
    this.height = 110,
  });

  final String label;
  final String iconPath;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.defaultCard,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            ..._kCardShadow,
            _softDropShadow(),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                Image.asset(
                  iconPath,
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTextStyle.bold18,
            ),
          ],
        ),
      ),
    );
  }
}
