import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../fields/app_text_field.dart';
import 'app_dialog.dart';

/// The one-field dialog behind every rename flow. Confirm stays disabled while
/// the text is empty or unchanged, so a non-null result (trimmed) is always
/// a real change; null means cancelled.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initialValue = '',
  String? confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final trimmed = value.text.trim();
        final hasChange = trimmed.isNotEmpty && trimmed != initialValue;
        return AppDialog(
          title: title,
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyle.bold14,
            decoration: appInputDecoration(hint: hint),
          ),
          primaryLabel: confirmLabel ?? l10n.save,
          onPrimary: hasChange ? () => Navigator.pop(ctx, trimmed) : null,
          secondaryLabel: l10n.cancel,
          onSecondary: () => Navigator.pop(ctx),
        );
      },
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  return result;
}
