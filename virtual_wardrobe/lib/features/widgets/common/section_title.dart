import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// Plain text label used above a form field or a list section.
class SectionTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SectionTitle(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style ?? AppTextStyle.bold14);
  }
}
