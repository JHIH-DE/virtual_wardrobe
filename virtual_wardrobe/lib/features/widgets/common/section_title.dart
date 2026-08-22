import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// Small-caps label used above a form field or a list section. Pass
/// [text] already uppercased — this doesn't transform it itself, so the
/// caller controls exactly what's shown (useful when only part of the
/// string, e.g. a unit suffix, shouldn't be capitalized).
class SectionTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SectionTitle(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style ?? AppTextStyle.overline12);
  }
}
