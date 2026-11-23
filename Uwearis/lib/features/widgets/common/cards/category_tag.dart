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

  /// Optional glyph before [label] (the outfit header's temperature).
  final IconData? icon;

  const CategoryTag({
    super.key,
    required this.label,
    this.borderColor,
    this.variant = CategoryTagVariant.standard,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isHeader = variant == CategoryTagVariant.header;
    final text = Text(
      label,
      style: AppTextStyle.bold12.copyWith(
        color: isHeader ? AppColors.headerChipText : AppColors.tagText,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: isHeader
            ? AppColors.headerChipBackground
            : AppColors.tagBackground,
        shape: StadiumBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
      ),
      child: icon == null ? text : _withIcon(text, isHeader),
    );
  }

  Widget _withIcon(Widget text, bool isHeader) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isHeader ? AppColors.headerChipIcon : AppColors.tagText,
        ),
        const SizedBox(width: 4),
        Flexible(child: text),
      ],
    );
  }
}
