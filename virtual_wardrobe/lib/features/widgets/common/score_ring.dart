import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// A circular "X%" progress ring — [score] out of 100 as the accent-colored
/// arc, the remainder as an [AppColors.borderSubtle] track, with an
/// [AppColors.accentTint] disc filling the ring's center.
class ScoreRing extends StatelessWidget {
  final int score;
  final double size;

  const ScoreRing({super.key, required this.score, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: score.clamp(0, 100) / 100,
              strokeWidth: size * 0.11,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.borderSubtle,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: const BoxDecoration(
              color: AppColors.accentTint,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            '$score%',
            style: AppTextStyle.bold18.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
