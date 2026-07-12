import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// Form field label with a trailing red required-field asterisk.
class RequiredFieldLabel extends StatelessWidget {
  final String label;

  const RequiredFieldLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyle.semibold14),
        const SizedBox(width: 4),
        Text('*', style: AppTextStyle.regular12.copyWith(color: Colors.red)),
      ],
    );
  }
}
