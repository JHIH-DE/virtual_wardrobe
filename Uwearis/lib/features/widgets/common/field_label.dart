import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// Label above a form field. Pass [title] already uppercased — it isn't
/// transformed, so e.g. a unit suffix can stay lowercase.
class FieldLabel extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const FieldLabel(this.title, {super.key, this.style});

  /// Chinese has no capitals, so the 12px small-caps size reads too small.
  static const double cjkFontSize = 14;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppTextStyle.overline12;
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    return Text(
      title,
      style: isChinese
          ? base.copyWith(fontSize: cjkFontSize, letterSpacing: 0)
          : base,
    );
  }
}
