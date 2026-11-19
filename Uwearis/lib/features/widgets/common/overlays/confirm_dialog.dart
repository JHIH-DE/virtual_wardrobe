import 'package:flutter/material.dart';

import 'app_dialog.dart';

/// The standard yes/no confirmation: [confirmLabel] as the primary (the
/// error fill with [destructive]) and AppDialog's own Cancel. True only for
/// [confirmLabel]; Cancel, a tap outside or a system back is false.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      body: body,
      primaryLabel: confirmLabel,
      destructive: destructive,
      onPrimary: () => Navigator.pop(ctx, true),
    ),
  );
  return confirmed == true;
}
