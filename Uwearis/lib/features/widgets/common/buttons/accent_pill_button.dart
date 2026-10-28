import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Solid accent pill for section-level call-outs. Disabled, it takes the
/// same grey fill + hint label as a disabled [ActionButton] primary.
///
/// The tap target is padded to [AppDimens.minTouchTarget] beyond the
/// [pillHeight] pill, since several call sites are AI triggers.
///
/// [disabledMessage] shows above a disabled pill; inline variant only, as
/// it's taller than a toolbar slot.
class AccentPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final AccentPillButtonVariant variant;
  final String? disabledMessage;

  /// Visible pill height at default text scale (both variants).
  static const double pillHeight = 36;

  const AccentPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.variant = AccentPillButtonVariant.inline,
    this.disabledMessage,
  }) : assert(
         disabledMessage == null || variant == AccentPillButtonVariant.inline,
       );

  @override
  Widget build(BuildContext context) {
    final background = enabled ? AppColors.accent : AppColors.borderSubtle;
    final foreground = enabled ? AppColors.textOnPrimary : AppColors.hintText;
    final onToolbar = variant == AccentPillButtonVariant.toolbar;
    final pill = TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        disabledForegroundColor: foreground,
        disabledBackgroundColor: background,
        minimumSize: const Size(0, pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      child: Text(
        label,
        style: (onToolbar ? AppTextStyle.bold15 : AppTextStyle.bold14).copyWith(
          color: foreground,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final button = GestureDetector(
      // Near-misses around the pill; direct hits still go to the button.
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppDimens.minTouchTarget),
        child: Center(widthFactor: 1, child: pill),
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
