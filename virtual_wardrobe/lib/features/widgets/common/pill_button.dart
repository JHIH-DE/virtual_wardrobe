import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// White rounded pill with a shadow, label and icon.
///
/// Default constructor matches the large bottom-toolbar action look (fixed
/// height, bordered, spaced-apart label/icon — e.g. Retake / Album).
/// [PillButton.floating] matches the compact look meant to float over
/// content via [Positioned] — e.g. an "Edit image" trigger.
class PillButton extends StatelessWidget {
  final Widget label;
  final Widget icon;
  final VoidCallback onTap;
  final double? height;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment mainAxisAlignment;
  final double gap;
  final BoxBorder? border;
  final List<BoxShadow> boxShadow;

  const PillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.height = 64,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.gap = 0,
    this.border = const Border.fromBorderSide(
      BorderSide(color: Colors.black12),
    ),
    this.boxShadow = const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 4)),
    ],
  });

  factory PillButton.floating({
    Key? key,
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return PillButton(
      key: key,
      label: Text(label, style: AppTextStyle.bold16),
      icon: icon,
      onTap: onTap,
      height: null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      mainAxisAlignment: MainAxisAlignment.start,
      gap: 8,
      border: null,
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: border,
          boxShadow: boxShadow,
        ),
        child: Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [
            label,
            if (gap > 0) SizedBox(width: gap),
            icon,
          ],
        ),
      ),
    );
  }
}
