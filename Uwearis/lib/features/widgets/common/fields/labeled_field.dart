import 'package:flutter/material.dart';

import '../field_label.dart';

/// A form field with its small-caps label stacked above it — the standard
/// "label + 8px gap + input" shape used across the garment / account /
/// AI-model forms. [label] is passed in normal case; this uppercases it for
/// the [FieldLabel] itself (every current call site was already doing
/// `.toUpperCase()` inline).
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  /// Optional inline extra shown right after the label — e.g. an
  /// "(OPTIONAL)" marker.
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
