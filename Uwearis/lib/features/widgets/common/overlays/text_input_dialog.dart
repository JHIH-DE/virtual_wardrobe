import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../fields/app_text_field.dart';
import 'app_dialog.dart';

/// A one-field text-input dialog: an [AppDialog] wrapping a single
/// autofocused [TextField]. This is the one dialog behind every rename flow
/// in the app (trip / outfit / garment) — they differ only in the
/// [title]/[hint] strings and what they do with the result.
///
/// Returns the trimmed text on confirm, or null if the user cancelled,
/// confirmed an empty value, or left it unchanged from [initialValue] — so
/// a caller can just `if (result != null)` and persist without a no-op
/// round trip.
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
    builder: (ctx) => AppDialog(
      title: title,
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: AppTextStyle.bold16,
        decoration: appInputDecoration(hint: hint),
      ),
      primaryLabel: confirmLabel ?? l10n.save,
      onPrimary: () => Navigator.pop(ctx, controller.text.trim()),
      secondaryLabel: l10n.cancel,
      onSecondary: () => Navigator.pop(ctx),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

  if (result == null || result.isEmpty || result == initialValue) return null;
  return result;
}
