import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// One tab of the frosted bottom nav bars ([MainNavBar], [ExploreNavBar]).
/// Must sit flush with the bar's top edge so the active marker hangs from it.
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

  static const double _markerHeight = 5;
  static const double _markerWidth = 24;

  /// From the tab's top edge to its icon's top.
  static const double _iconTop = 12;

  /// The gap between the tap highlight and the bar's top edge — and, via
  /// [NavBarTabRow], its bottom edge too, so the highlight is centered.
  static const double _highlightInset = 6;
  static const double _horizontalPadding = 6;
  static const double _iconSize = 24;
  static const double _labelGap = 3;

  /// Under the label.
  static const double _labelBottomPadding = 4;

  static TextStyle get _labelStyle =>
      AppTextStyle.regular12.copyWith(fontWeight: FontWeight.w700);

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
    final color = isActive ? AppColors.textOnPrimary : AppColors.navBarInactive;
    // The marker hangs from the bar's top edge, outside the tap highlight,
    // which starts [_highlightInset] below it.
    return Semantics(
      selected: isActive,
      button: true,
      child: Stack(
        // Keeps the row's width for the tab, so the highlight fills it.
        fit: StackFit.passthrough,
        children: [
          Padding(
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
                      style: AppTextStyle.regular12.copyWith(
                        color: color,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: isActive ? _markerWidth : 0,
                height: _markerHeight,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(_markerHeight),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The content of a round-ended nav bar: its [NavBarTab]s (plus any
/// fixed-width [SizedBox] gap), evenly spaced, with each end inset just
/// enough that the outer tab's active marker (which hangs from the bar's top
/// edge) stays on the straight part of the outline, clear of the curve.
///
/// Every tab gets the same width — [tabWidth], or more when enlarged text
/// needs it — as long as that still fits every label whole. When it can't
/// (narrow screen, enlarged text), readability wins: tabs fall back to their
/// own widths, and only if even those don't fit do they shrink in
/// proportion with ellipsized labels.
class NavBarTabRow extends StatelessWidget {
  /// Fits the widest current label (為你推薦) at the default text size.
  static const double tabWidth = 60;

  /// How far the marker may reach into the curve: at 8px the curve has
  /// dropped only ~1px, under the marker's own rounded corner.
  static const double _markerCurveOverlap = 8;

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
    // centered marker, icon and label clear the curve. The marker may reach
    // [_markerCurveOverlap] past where the curve starts.
    double endInset(double w, double natural) {
      final label = natural - 2 * NavBarTab._horizontalPadding;
      return [
        0.0,
        radius - _markerCurveOverlap - (w - NavBarTab._markerWidth) / 2,
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
