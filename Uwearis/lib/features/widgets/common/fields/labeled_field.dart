import 'package:flutter/material.dart';

import '../field_label.dart';

/// A form field with its label above. Pass [label] in normal case; it's
/// uppercased here.
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  /// Shown right after the label, e.g. an "(OPTIONAL)" marker.
  final Widget? labelTrailing;

  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.labelTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = labelTrailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trailing == null)
          FieldLabel(label.toUpperCase())
        else
          Row(
            children: [
              FieldLabel(label.toUpperCase()),
              const SizedBox(width: 4),
              trailing,
            ],
          ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
