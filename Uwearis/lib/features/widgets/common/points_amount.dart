import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../app/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// A points amount as the app shows it everywhere: an accent "P", then the
/// locale-formatted number in [style].
class PointsAmount extends StatelessWidget {
  final int points;
  final TextStyle? style;

  const PointsAmount(this.points, {super.key, this.style});

  /// The same amount as a span, for a caller that measures it or adds text
  /// after it. Inherits its style from the enclosing span.
  static TextSpan span(BuildContext context, int points) {
    final l10n = AppLocalizations.of(context);
    return TextSpan(
      children: [
        TextSpan(
          text: '${l10n.aiCreditsSymbol} ',
          style: const TextStyle(color: AppColors.accent),
        ),
        TextSpan(
          text: NumberFormat.decimalPattern(l10n.localeName).format(points),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(style: style, children: [span(context, points)]));
  }
}
