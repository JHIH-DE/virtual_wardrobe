import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// Label above a form field. Pass [title] already uppercased — it isn't
/// transformed, so e.g. a unit suffix can stay lowercase.
class FieldLabel extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const FieldLabel(this.title, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: style ?? AppTextStyle.overline12);
  }
}
