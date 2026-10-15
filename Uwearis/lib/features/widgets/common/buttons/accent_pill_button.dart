import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Outlined accent pill for secondary call-outs; the outlined sibling of
/// [PillButton].
///
/// The tap target is padded to [AppDimens.minTouchTarget] beyond the
/// 28px (toolbar: 32px) pill, since several call sites are AI triggers.
///
/// [disabledMessage] shows above a disabled pill; inline variant only, as
/// it's taller than a toolbar slot.
class AccentPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final AccentPillButtonVariant variant;
  final String? disabledMessage;

  const AccentPillButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.variant = AccentPillButtonVariant.inline,
    this.disabledMessage,
  }) : assert(
         disabledMessage == null || variant == AccentPillButtonVariant.inline,
       );

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.accent : AppColors.hintText;
    final onToolbar = variant == AccentPillButtonVariant.toolbar;
    final pill = TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: Size(0, onToolbar ? 32 : 28),
        padding: EdgeInsets.symmetric(horizontal: onToolbar ? 12 : 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        side: BorderSide(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: onToolbar ? 17 : 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: (onToolbar ? AppTextStyle.bold15 : AppTextStyle.bold14)
                  .copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final button = Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        // Near-misses around the pill; direct hits still go to the button.
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDimens.minTouchTarget,
          ),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );

    final message = disabledMessage;
    if (enabled || message == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyle.regular13.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        button,
      ],
    );
  }
}

/// Where an [AccentPillButton] sits.
enum AccentPillButtonVariant {
  /// Beside a section header or in page content.
  inline,

  /// In an AppToolBar's leading slot (Home's "Explore", Explore's "Home").
  toolbar,
}
