import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Small inline error message shown above a form while the form itself
/// stays visible — as opposed to [ErrorStateWidget], which replaces the
/// whole page with a centered icon + retry button.
class InlineErrorText extends StatelessWidget {
  final String message;
  final EdgeInsetsGeometry padding;

  const InlineErrorText({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        message,
        style: AppTextStyle.regular13.copyWith(color: AppColors.error),
      ),
    );
  }
}
