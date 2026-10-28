import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// One tab of the frosted bottom nav bars ([MainNavBar], [ExploreNavBar]).
class NavBarTab extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const NavBarTab({
    super.key,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  /// From the tab's top edge to its icon's top.
  static const double _iconTop = 9;

  /// The gap between the tap highlight and the bar's top edge — and, via
  /// [NavBarTabRow], its bottom edge too, so the highlight is centered.
  static const double _highlightInset = 6;
  static const double _horizontalPadding = 4;
  static const double _iconSize = 28;
  static const double _labelGap = 3;

  /// Under the label.
  static const double _labelBottomPadding = 1;

  static TextStyle get _labelStyle =>
      AppTextStyle.regular13.copyWith(fontWeight: FontWeight.w700);

  /// This tab's height at [context]'s text scale.
  static double heightFor(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height =
        _iconTop + _iconSize + _labelGap + painter.height + _labelBottomPadding;
    painter.dispose();
    return height;
  }

  /// The width this tab takes at [context]'s text scale when nothing
  /// constrains it — measured with the active (bold) label, the wider one.
  static double naturalWidthFor(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // Rounded up: a box exactly the painted width can still ellipsize.
    final width =
        math.max(_iconSize, painter.width.ceilToDouble()) +
        2 * _horizontalPadding;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.navBarInactive;
    return Semantics(
      selected: isActive,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(top: _highlightInset),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _horizontalPadding,
              _iconTop - _highlightInset,
              _horizontalPadding,
              _labelBottomPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? activeIcon : inactiveIcon,
                  color: color,
                  size: _iconSize,
                ),
                const SizedBox(height: _labelGap),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.regular13.copyWith(
                    color: color,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The content of a round-ended nav bar: its [NavBarTab]s (plus any
/// fixed-width [SizedBox] gap), evenly spaced, with each end inset just
/// enough that the outer tab's icon and label stay clear of the curve.
///
/// Every tab gets the same width — [tabWidth], or more when enlarged text
/// needs it — as long as that still fits every label whole. When it can't
/// (narrow screen, enlarged text), readability wins: tabs fall back to their
/// own widths, and only if even those don't fit do they shrink in
/// proportion with ellipsized labels.
class NavBarTabRow extends StatelessWidget {
  /// Fits the widest current label (為你推薦) at the default text size.
  static const double tabWidth = 60;

  final List<Widget> children;

  const NavBarTabRow({super.key, required this.children});

  /// The bar's height, and so twice its end radius, at [context]'s text
  /// scale.
  static double barHeightFor(BuildContext context) =>
      NavBarTab.heightFor(context) + NavBarTab._highlightInset;

  @override
  Widget build(BuildContext context) {
    final radius = barHeightFor(context) / 2;
    // How far in from the bar's end the outline is at [fromCenter] above or
    // below its middle.
    double curveAt(double fromCenter) =>
        radius -
        math.sqrt(math.max(0, radius * radius - fromCenter * fromCenter));
    final labelBottomCurve = curveAt(
      radius - NavBarTab._highlightInset - NavBarTab._labelBottomPadding,
    );
    final iconTopCurve = curveAt(radius - NavBarTab._iconTop);

    // The inset an outer tab [w] wide (natural width [natural]) needs so its
    // centered icon and label clear the curve.
    double endInset(double w, double natural) {
      final label = natural - 2 * NavBarTab._horizontalPadding;
      return [
        0.0,
        iconTopCurve - (w - NavBarTab._iconSize) / 2,
        labelBottomCurve - (w - math.min(label, w)) / 2,
      ].reduce(math.max);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final natural = <double?>[];
        var fixed = 0.0;
        for (final child in children) {
          switch (child) {
            case NavBarTab(:final label):
              natural.add(NavBarTab.naturalWidthFor(context, label));
            case SizedBox(:final width?):
              natural.add(null);
              fixed += width;
            default:
              natural.add(null);
          }
        }
        final tabs = natural.whereType<double>().toList();
        final widest = tabs.fold(0.0, math.max);
        final available = constraints.maxWidth - fixed;

        double insets(List<double> widths) =>
            endInset(widths.first, tabs.first) +
            endInset(widths.last, tabs.last);
        bool fits(List<double> widths) =>
            widths.fold(0.0, (a, b) => a + b) + insets(widths) <= available;

        final equal = math.max(tabWidth, widest);
        final List<double> widths;
        final bool shrink;
        if (fits([for (final _ in tabs) equal])) {
          widths = [for (final _ in tabs) equal];
          shrink = false;
        } else if (fits(tabs)) {
          widths = tabs;
          shrink = false;
        } else {
          // Scale the natural widths down until they and their end insets
          // fit; the insets grow as the outer tabs narrow, so iterate.
          var scaled = tabs;
          for (var i = 0; i < 4; i++) {
            final room = available - insets(scaled);
            final factor = room / tabs.fold(0.0, (a, b) => a + b);
            scaled = [for (final w in tabs) w * factor];
          }
          widths = scaled;
          shrink = true;
        }

        var t = 0;
        final row = <Widget>[
          for (var i = 0; i < children.length; i++)
            if (natural[i] == null)
              children[i]
            else if (shrink)
              Flexible(flex: (widths[t++] * 100).round(), child: children[i])
            else
              SizedBox(width: widths[t++], child: children[i]),
        ];
        return Padding(
          padding: EdgeInsets.fromLTRB(
            endInset(widths.first, tabs.first),
            0,
            endInset(widths.last, tabs.last),
            NavBarTab._highlightInset,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row,
          ),
        );
      },
    );
  }
}

/// The frosted-glass surface of the bottom nav bars and [MainNavBar]'s
/// quick-action menu, in [clipper]'s outline: blurred page behind a tinted
/// fill with a top sheen, a lit top edge and shaded bottom edge for
/// thickness, a hairline rim, and a soft shadow.
class NavBarGlass extends StatelessWidget {
  final CustomClipper<Path> clipper;
  final Widget child;

  const NavBarGlass({super.key, required this.clipper, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NavBarGlassShadowPainter(clipper),
      foregroundPainter: _NavBarGlassRimPainter(clipper),
      child: ClipPath(
        clipper: clipper,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.navBarGlassTop, AppColors.navBarGlassBottom],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navBarGlassSheen,
                    AppColors.navBarGlassSheen.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.5],
                ),
              ),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints only outside the outline: an elevation shadow would show through
/// the translucent glass and grey it.
class _NavBarGlassShadowPainter extends CustomPainter {
  final CustomClipper<Path> clipper;

  const _NavBarGlassShadowPainter(this.clipper);

  @override
  void paint(Canvas canvas, Size size) {
    final outline = clipper.getClip(size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(48)),
      outline,
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawPath(
        outline.shift(const Offset(0, 6)),
        Paint()
          ..color = AppColors.shadowResting
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_NavBarGlassShadowPainter oldDelegate) =>
      oldDelegate.clipper != clipper;
}

class _NavBarGlassRimPainter extends CustomPainter {
  final CustomClipper<Path> clipper;

  const _NavBarGlassRimPainter(this.clipper);

  @override
  void paint(Canvas canvas, Size size) {
    final outline = clipper.getClip(size);
    final bounds = Offset.zero & size;
    // Clipped to the outline, so only the inner half of each stroke shows.
    Paint innerEdge(List<Color> colors, List<double> stops) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(bounds);
    canvas
      ..save()
      ..clipPath(outline)
      ..drawPath(
        outline,
        innerEdge(
          [
            AppColors.navBarGlassHighlight,
            AppColors.navBarGlassHighlight.withValues(alpha: 0),
          ],
          const [0, 0.5],
        ),
      )
      ..drawPath(
        outline,
        innerEdge(
          [
            AppColors.navBarGlassShade.withValues(alpha: 0),
            AppColors.navBarGlassShade,
          ],
          const [0.5, 1],
        ),
      )
      ..restore()
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.borderSubtle,
      );
  }

  @override
  bool shouldRepaint(_NavBarGlassRimPainter oldDelegate) =>
      oldDelegate.clipper != clipper;
}
