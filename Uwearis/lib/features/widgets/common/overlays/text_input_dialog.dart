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
/// The primary button stays disabled (per [AppDialog]'s nullable `onPrimary`
/// — see CLAUDE.md's "Dialog primary button disabled state") while the
/// field is empty or unchanged from [initialValue], so there's no no-op
/// submit to guard against after the dialog closes.
///
/// Returns the trimmed text on confirm, or null if the user cancelled — a
/// caller can just `if (result != null)` and persist.
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
            style: AppTextStyle.bold16,
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

  // onPrimary only pops with a value once hasChange is true, so a non-null
  // result here is already guaranteed non-empty and different from
  // initialValue — nothing left to re-check.
  return result;
}
