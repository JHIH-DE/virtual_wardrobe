import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// Small-caps label above a single form field — e.g. Garment Details'
/// field titles (Category, Product Type, ...), Account's name/gender/
/// birthday fields, Add Outfit's per-slot label (Top, Bottom, ...). Pass
/// [title] already uppercased — this doesn't transform it itself, so the
/// caller controls exactly what's shown (useful when only part of the
/// string, e.g. a unit suffix, shouldn't be capitalized).
class FieldLabel extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const FieldLabel(this.title, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: style ?? AppTextStyle.overline12);
  }
}
