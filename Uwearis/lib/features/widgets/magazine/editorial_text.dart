import 'package:flutter/material.dart';

import '../../../app/theme/editorial_typography.dart';

/// Editorial text in one [EditorialTextStyle] role.
class EditorialText extends StatelessWidget {
  final String text;
  final EditorialTextStyle style;

  const EditorialText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) => Text.rich(style.span(text));
}

/// Lays editorial text out as [EditorialText] renders it in a context: the
/// same spans over the same default style, locale, text scale, direction
/// and line-height behaviour, so a layout can size what's left around it.
class EditorialTextMeasure {
  final TextStyle _base;
  final TextScaler _scaler;
  final TextDirection _direction;
  final Locale? _locale;
  final TextHeightBehavior? _heightBehavior;
  final TextWidthBasis _widthBasis;

  EditorialTextMeasure(BuildContext context)
    : _base = DefaultTextStyle.of(context).style,
      _scaler = MediaQuery.textScalerOf(context),
      _direction = Directionality.of(context),
      _locale = Localizations.maybeLocaleOf(context),
      _heightBehavior =
          DefaultTextHeightBehavior.maybeOf(context) ??
          DefaultTextStyle.of(context).textHeightBehavior,
      _widthBasis = DefaultTextStyle.of(context).textWidthBasis;

  TextScaler get textScaler => _scaler;

  /// [text]'s height at [width]; 0 for none.
  double height(String? text, EditorialTextStyle style, double width) {
    if (text == null) return 0;
    final painter = TextPainter(
      text: TextSpan(style: _base, children: [style.span(text)]),
      textDirection: _direction,
      textScaler: _scaler,
      locale: _locale,
      textHeightBehavior: _heightBehavior,
      textWidthBasis: _widthBasis,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
