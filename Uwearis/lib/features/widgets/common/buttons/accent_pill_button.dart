import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Compact outlined pill — transparent fill, fully-rounded [AppColors.accent]
/// border with a matching leading icon and label. The outlined-accent
/// sibling of [PillButton] (which is the filled white-with-shadow style).
///
/// Used for lightweight, secondary call-outs that sit inside a toolbar or
/// beside a section header (Home's "Explore", Add Outfit's "Complete with
/// AI").
///
/// When [enabled] is false the whole pill greys out and taps are ignored.
/// [onPressed] may be null while a feature is still visual-only — the pill
/// then looks active but does nothing.
class AccentPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  const AccentPillButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.accent : AppColors.hintText;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label, style: AppTextStyle.bold14.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
