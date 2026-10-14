import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// The translucent disc behind a header action glyph — every icon action on
/// [AppToolBar] (back button, "⋮" menu, filter, page-specific actions) and a
/// [pageSheet]'s header actions. Visual only; [ActionDiscButton] wraps it in
/// the toolbar-height tap target. Size the [child] glyph to [iconSize].
class ActionDisc extends StatelessWidget {
  static const double size = 40;
  static const double iconSize = 22;

  /// How far a [AppDimens.toolbarHeight] tap box sits from the screen /
  /// sheet edge so its disc lands 20 from that edge, as on iOS.
  static const double edgeInset = 20 - (AppDimens.toolbarHeight - size) / 2;

  final Widget child;

  const ActionDisc({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _OuterShadowPainter(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              AppColors.actionDiscFillCenter,
              AppColors.actionDiscFillEdge,
            ],
          ),
          border: Border.all(color: AppColors.actionDiscRim, width: 0.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner highlight on the top and bottom edges only, fading out
            // towards the sides.
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface,
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.surface,
                  ],
                  stops: [0, 0.3, 0.7, 1],
                ).createShader(bounds),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// A soft drop shadow clipped to outside the disc — the fill is translucent,
/// so a plain [BoxShadow] would grey the disc from underneath.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Path()..addOval(Offset.zero & size);
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(8)),
          circle,
        ),
      )
      ..drawPath(
        circle.shift(const Offset(0, 1)),
        Paint()
          ..color = AppColors.shadowResting
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) => false;
}

/// An [ActionDisc] in a [AppDimens.toolbarHeight] square tap target — the
/// shape of every icon action on [AppToolBar].
class ActionDiscButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const ActionDiscButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final Widget button = Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: AppDimens.toolbarHeight,
          child: Center(child: ActionDisc(child: icon)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
