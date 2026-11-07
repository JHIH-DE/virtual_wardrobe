import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The user's AI credit balance. Hugs its content, with the amount's slot
/// sized for [_maxCredits] so the bar keeps its width as the balance changes.
class AiCreditsBar extends StatelessWidget {
  final int credits;

  const AiCreditsBar({super.key, required this.credits});

  static const _maxCredits = 10000;
  static final _textStyle = AppTextStyle.medium14.copyWith(
    color: AppColors.headerChipText,
  );

  static double _textWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _textStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern(l10n.localeName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: const ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: AppColors.borderStrong)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.aiCreditsLabel, style: _textStyle),
          SizedBox(
            width: 8 + _textWidth(context, numberFormat.format(_maxCredits)),
            child: Text(
              numberFormat.format(credits),
              textAlign: TextAlign.end,
              style: _textStyle,
            ),
          ),
        ],
      ),
    );
  }
}
