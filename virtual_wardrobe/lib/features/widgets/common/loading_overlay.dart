import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

class LoadingOverlay extends StatelessWidget {
  final String label;

  const LoadingOverlay({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.defaultMask,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppColors.textPrimaryInv,
            strokeWidth: 5,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/ai_process_inv.png',
                width: AppDimens.iconSmallSize,
                height: AppDimens.iconSmallSize,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyle.bold16.copyWith(
                  color: AppColors.textPrimaryInv,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
