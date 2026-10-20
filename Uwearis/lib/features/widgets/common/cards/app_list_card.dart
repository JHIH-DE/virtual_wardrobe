import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../adaptive_side_layout.dart';

class AppListCard extends StatelessWidget {
  final String? title;
  final VoidCallback? onTap;
  final Widget child;
  final bool showArrow;
  final String? leadingAsset;
  final Widget? leading;
  final String? status;
  final String? summary;
  final double minHeight;
  final double leadingSize;
  final Widget? trailing;

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
    this.minHeight = 54,
    this.leadingSize = 40,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // Enlarged text: [status] moves under the title instead of squeezing it
    // into a sliver.
    final textEnlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
    final statusText = status == null
        ? null
        : Text(
            status!,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          );
    // A leading decoration moves above the text when a long word at the
    // current text size wouldn't fit beside it, rather than breaking it.
    final leadingWidget =
        leading ??
        (leadingAsset == null
            ? null
            : Image.asset(
                leadingAsset!,
                width: leadingSize,
                height: leadingSize,
              ));
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(title!, style: AppTextStyle.bold16),
          const SizedBox(height: 2),
        ],
        child,
        if (statusText != null && textEnlarged) ...[
          const SizedBox(height: 2),
          statusText,
        ],
        if (summary != null) ...[
          const SizedBox(height: 2),
          Text(
            summary!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.regular12.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: leadingWidget == null
              ? textColumn
              : AdaptiveSideLayout(
                  sideEdge: AdaptiveSide.leading,
                  side: leadingWidget,
                  content: textColumn,
                  gap: 18,
                  stackedGap: 8,
                ),
        ),
        if (statusText != null && !textEnlarged) ...[
          const SizedBox(width: 8),
          statusText,
        ],
        if (showArrow && onTap != null) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: AppDimens.iconSmallSize,
            color: AppColors.hintText,
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );

    final card = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFaint,
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
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: card,
      );
    }
    return card;
  }
}
