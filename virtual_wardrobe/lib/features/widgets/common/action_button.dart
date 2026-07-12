import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Icon-over-label tap target, e.g. Favorite / Share / Used in Looks.
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: iconColor ?? AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
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
      child: Row(
        children: [for (final b in buttons) Expanded(child: b)],
      ),
    );
  }
}
