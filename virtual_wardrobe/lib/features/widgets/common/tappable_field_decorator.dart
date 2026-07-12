import 'package:flutter/material.dart';

import 'app_text_field.dart';

/// Tappable row styled like a text field (picker/date-field trigger) —
/// an [InkWell] wrapping an [InputDecorator] with custom [Row] content.
class TappableFieldDecorator extends StatelessWidget {
  final VoidCallback onTap;
  final List<Widget> children;

  const TappableFieldDecorator({
    super.key,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: appInputDecoration(hint: ''),
        child: Row(children: children),
      ),
    );
  }
}
