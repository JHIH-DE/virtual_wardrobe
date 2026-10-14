import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// Compact circular icon button — a glass disc with an [AppColors.icon]
/// glyph at half its [size]. The one design for every in-page round icon
/// action (Outfit Details' tag editor, Trip Details' Replan / Change
/// Garments), on the cream page and on white cards alike.
///
/// The visible disc stays [size] wide, but the tap target is padded out
/// (transparently) to at least [AppDimens.minTouchTarget] so a near-miss
/// around the disc still registers. [discAlignment] places the disc inside
/// that larger box — `Alignment.centerRight` lines its edge up with content
/// at the end of a row, the extra tap area growing inward instead.
///
/// When [enabled] is false the button greys out and taps are ignored.
/// [onPressed] may be null while a feature is still visual-only — the
/// button then looks active but does nothing. [tooltip] also labels the
/// button for screen readers.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? tooltip;
  final Alignment discAlignment;

  /// Diameter of the disc; the glyph renders at half this.
  final double size;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.tooltip,
    this.discAlignment = Alignment.center,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.icon : AppColors.hintText;
    final button = Opacity(
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
          child: Align(
            alignment: discAlignment,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The fade to clear stays white (not Colors.transparent,
                // which is clear *black* and greys the blend), so only the
                // outer rim picks up the darker edge tone.
                gradient: RadialGradient(
                  colors: [
                    AppColors.iconButtonFillCenter,
                    AppColors.iconButtonFillCenter.withValues(alpha: 0),
                    AppColors.iconButtonFillEdge,
                  ],
                  stops: const [0, 0.7, 1],
                ),
                // Outer-only, so it doesn't grey the translucent fill.
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowResting,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    blurStyle: BlurStyle.outer,
                  ),
                ],
              ),
              position: DecorationPosition.background,
              child: DecoratedBox(
                // Top sheen — reads on white too, since the edge under it
                // is darker than the card.
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.iconButtonRim,
                    width: 0.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.iconButtonSheen,
                      AppColors.iconButtonSheen.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.45],
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
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
        ),
      ),
    );
    final label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}
