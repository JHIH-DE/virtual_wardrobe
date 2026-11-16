import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../app/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// A points amount as the app shows it everywhere: an accent coin icon, then
/// the locale-formatted number in [style].
class PointsAmount extends StatelessWidget {
  final int points;
  final TextStyle? style;

  const PointsAmount(this.points, {super.key, this.style});

  /// Lucide `circle-star` at the Lucide300 stroke, with the viewBox cropped to
  /// the stroke's outer edge so the box is exactly the visible ring.
  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="1.225 1.225 21.55 21.55" '
      'fill="none" stroke="#000" stroke-width="1.55" stroke-linecap="round" '
      'stroke-linejoin="round"><circle cx="12" cy="12" r="10"/>'
      '<path d="M11.051 7.616a1 1 0 0 1 1.909.024l.737 1.452a1 1 0 0 0 .737.535'
      'l1.634.256a1 1 0 0 1 .588 1.806l-1.172 1.168a1 1 0 0 0-.282.866l.259 '
      '1.613a1 1 0 0 1-1.541 1.134l-1.465-.75a1 1 0 0 0-.912 0l-1.465.75a1 1 0 '
      '0 1-1.539-1.133l.258-1.613a1 1 0 0 0-.282-.867l-1.156-1.152a1 1 0 0 1 '
      '.572-1.822l1.633-.256a1 1 0 0 0 .737-.535z"/></svg>';

  /// NotoSansTC's digit height. The icon sits on the baseline at this height,
  /// so it lines up with the digits top and bottom.
  static const _digitHeight = 0.73;

  static double _digitSize(BuildContext context, double fontSize) =>
      MediaQuery.textScalerOf(context).scale(fontSize) * _digitHeight;

  /// What a TextPainter measuring [span] needs for its one placeholder.
  static List<PlaceholderDimensions> placeholderDimensions(
    BuildContext context, {
    required double fontSize,
    double iconScale = 1,
  }) {
    final digits = _digitSize(context, fontSize);
    return [
      PlaceholderDimensions(
        size: Size(digits * iconScale, digits),
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
      ),
    ];
  }

  /// The same amount as a span, for a caller that measures it or adds text
  /// after it. Inherits its style from the enclosing span, whose font size
  /// the caller passes as [fontSize].
  ///
  /// [iconScale] enlarges the icon relative to the digits for small text; it
  /// stays centred on them and the line keeps its height.
  static TextSpan span(
    BuildContext context,
    int points, {
    required double fontSize,
    double iconScale = 1,
  }) {
    final l10n = AppLocalizations.of(context);
    final digits = _digitSize(context, fontSize);
    final size = digits * iconScale;
    return TextSpan(
      children: [
        // These boxes have no baseline of their own, so baseline alignment
        // puts the digit-high box's bottom edge on the text baseline.
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(
            width: size,
            height: digits,
            child: OverflowBox(
              maxHeight: size,
              child: SvgPicture.string(
                _svg,
                width: size,
                height: size,
                colorFilter: const ColorFilter.mode(
                  AppColors.accent,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        const TextSpan(text: ' '),
        TextSpan(
          text: NumberFormat.decimalPattern(l10n.localeName).format(points),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize =
        style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    return Text.rich(
      TextSpan(
        style: style,
        children: [span(context, points, fontSize: fontSize)],
      ),
    );
  }
}
