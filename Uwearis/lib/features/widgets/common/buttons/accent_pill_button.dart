import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Compact outlined pill — transparent fill, fully-rounded [AppColors.accent]
/// border with a matching leading icon and label. The outlined-accent
/// sibling of [PillButton] (which is the filled white-with-shadow style).
///
/// Used for lightweight, secondary call-outs that sit inside a toolbar or
/// beside a section header (Home's "Explore", Add Outfit's "Complete with
/// AI").
///
/// The visible pill stays 28px tall ([AccentPillButtonVariant.toolbar]: 32,
/// with a larger icon and label to match the AppToolBar's scale), but the tap target is padded out
/// (transparently) to [AppDimens.minTouchTarget] so a near-miss above/below
/// the pill still registers — several call sites are AI-render triggers.
///
/// When [enabled] is false the whole pill greys out and taps are ignored.
/// [onPressed] may be null while a feature is still visual-only — the pill
/// then looks active but does nothing.
class AccentPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final AccentPillButtonVariant variant;

  const AccentPillButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.variant = AccentPillButtonVariant.inline,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.accent : AppColors.hintText;
    final onToolbar = variant == AccentPillButtonVariant.toolbar;
    // A TextButton, so the press feedback is the same Material state-layer
    // overlay as AppDialog's "Cancel" / "Don't Save" — a soft tint on tap,
    // not an InkWell ripple.
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

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        // Catches near-misses in the transparent band above/below the
        // pill; the inner InkWell still owns direct hits and the ripple, and
        // the gesture arena resolves a tap on the pill to it, not to this.
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDimens.minTouchTarget,
          ),
          // widthFactor keeps a Row/Wrap seeing the pill's real width (so
          // surrounding spacing is unchanged); the Center only grows
          // vertically to fill the min-height band.
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
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
