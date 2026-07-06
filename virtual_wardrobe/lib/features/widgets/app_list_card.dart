import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';

class AppListCard extends StatelessWidget {
  final String? title;
  final VoidCallback? onTap;
  final Widget child;
  final bool showArrow;
  final String? leadingAsset;
  final Widget? leading;
  final String? status;
  final String? summary;

  const AppListCard({
    super.key,
    this.title,
    this.onTap,
    required this.child,
    this.showArrow = false,
    this.leadingAsset,
    this.leading,
    this.status,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null || leadingAsset != null) ...[
          leading ?? Image.asset(leadingAsset!, width: 40, height: 40),
          const SizedBox(width: 18),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(title!, style: AppTextStyle.bold14),
                const SizedBox(height: 10),
              ],
              child,
              if (summary != null) ...[
                const SizedBox(height: 2),
                Text(
                  summary!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.regular12.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (status != null) ...[
          const SizedBox(width: 8),
          Text(status!, style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary)),
        ],
        if (showArrow && onTap != null) ...[
          const SizedBox(width: 4),
          Image.asset('assets/images/page_arrow_right.png', width: AppDimens.iconSmallSize, height: AppDimens.iconSmallSize),
        ],
      ],
    );

    final card = Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }
    return card;
  }
}
