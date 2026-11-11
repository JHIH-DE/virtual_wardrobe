import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// White pill with a dark label, for a call-out sitting on a photo (Explore's
/// Read), where the accent fill of [AccentPillButton] would clash.
///
/// The tap target is padded to [AppDimens.minTouchTarget] beyond the
/// [pillHeight] pill.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Visible pill height at default text scale.
  static const double pillHeight = 36;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = enabled ? AppColors.surface : AppColors.borderSubtle;
    final foreground = enabled ? AppColors.textPrimary : AppColors.hintText;
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
        style: AppTextStyle.bold14.copyWith(color: foreground),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return GestureDetector(
      // Near-misses around the pill; direct hits still go to the button.
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppDimens.minTouchTarget),
        child: Center(widthFactor: 1, child: pill),
      ),
    );
  }
}
