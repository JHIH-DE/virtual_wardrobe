import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// Heading for a block of content within a page — e.g. Lifestyle's
/// "Weekly Schedule"/"Comfort Adjustment", Add Outfit's "Accessories"/
/// "Scene", AI Model's "Face Reference"/"Body Reference"/"Body
/// Measurements". One step down from the page's own AppBar title, one
/// step up from a [FieldLabel]. Unlike [FieldLabel], this isn't
/// small-caps — pass [title] in normal case.
class SectionTitle extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const SectionTitle(this.title, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: style ?? AppTextStyle.bold18);
  }
}
