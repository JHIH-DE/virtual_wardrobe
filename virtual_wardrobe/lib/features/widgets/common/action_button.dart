import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Icon+label tap target, e.g. Favorite / Share / Used in Looks. Stacked
/// (icon above label) by default; set [horizontal] for icon-beside-label.
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool horizontal;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 24, color: iconColor ?? AppColors.icon);
    final labelWidget = Text(
      label,
      style: AppTextStyle.regular14.copyWith(color: AppColors.textPrimary),
    );

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: horizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [iconWidget, const SizedBox(width: 8), labelWidget],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [iconWidget, const SizedBox(height: 4), labelWidget],
              ),
      ),
    );
  }
}

/// Evenly-spaced row of [ActionButton]s, each stretched to the row's height.
class ActionButtonRow extends StatelessWidget {
  final List<ActionButton> buttons;

  const ActionButtonRow({super.key, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(children: [for (final b in buttons) Expanded(child: b)]),
    );
  }
}
