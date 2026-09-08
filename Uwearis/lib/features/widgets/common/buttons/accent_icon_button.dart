import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// Compact circular icon button — an [AppColors.accentTint] disc with an
/// [AppColors.accent] glyph. The icon-only sibling of [AccentPillButton]
/// (outlined pill) and [PillButton] (filled).
///
/// The visible disc stays [size] wide, but the tap target is padded out
/// (transparently) to at least [AppDimens.minTouchTarget] so a near-miss
/// around the disc still registers.
///
/// When [enabled] is false the button greys out and taps are ignored.
/// [onPressed] may be null while a feature is still visual-only — the
/// button then looks active but does nothing.
class AccentIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Diameter of the disc; the glyph renders at half this.
  final double size;

  const AccentIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.accent : AppColors.hintText;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        // Catches near-misses in the transparent ring that pads the visible
        // disc out to AppDimens.minTouchTarget. The inner InkWell still owns
        // direct hits (and the ripple); the gesture arena resolves a tap on
        // the disc to it, not to this, so onPressed never fires twice.
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: SizedBox.square(
          dimension: math.max(size, AppDimens.minTouchTarget),
          child: Center(
            child: Material(
              color: AppColors.accentTint,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                child: SizedBox.square(
                  dimension: size,
                  child: Center(
                    child: Icon(icon, size: size / 2, color: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
