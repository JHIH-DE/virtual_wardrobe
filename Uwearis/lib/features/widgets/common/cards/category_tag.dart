import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

enum CategoryTagVariant {
  standard,

  /// Metadata under a page title (Outfit Details / Today's Outfit's tag
  /// line), colored like Home's header pills.
  header,
}

class CategoryTag extends StatelessWidget {
  final String label;
  final Color? borderColor;
  final CategoryTagVariant variant;

  const CategoryTag({
    super.key,
    required this.label,
    this.borderColor,
    this.variant = CategoryTagVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final isHeader = variant == CategoryTagVariant.header;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isHeader
            ? AppColors.headerChipBackground
            : AppColors.tagBackground,
        borderRadius: BorderRadius.circular(4),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: AppTextStyle.bold12.copyWith(
          color: isHeader ? AppColors.headerChipText : AppColors.tagText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
