import 'package:flutter/material.dart';

import '../../../../core/services/auth_handler.dart';
import '../../../../core/utils/api_error_text.dart';
import '../../../../core/utils/auto_save_controller.dart';
import '../../../../core/utils/debug_log.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'error_dialog.dart';
import 'save_changes_dialog.dart';

// The UI half of [AutoSaveController]. The `is AuthExpiredException` checks
// inspect an error value from the controller, not a `catch` clause.

/// [AutoSaveController.onError] handler: an error dialog whose Retry
/// re-requests the save.
Future<void> showAutoSaveErrorDialog(
  BuildContext context,
  AutoSaveController controller,
  Object error, {
  required String fallback,
}) async {
  if (!context.mounted) return;
  if (error is AuthExpiredException) {
    await AuthExpiredHandler.handle(context);
    return;
  }
  debugLog('auto-save failed: $error');
  final l10n = AppLocalizations.of(context);
  await showErrorDialog(
    context,
    message: apiErrorMessage(l10n, error, fallback: fallback),
    onRetry: controller.requestSave,
  );
}

/// Flushes pending changes before leaving; on failure asks via
/// [showSaveChangesDialog]. Returns whether the page should pop.
///
/// [onFlushingChanged] brackets only waits with a real save to push (never
/// the dialog), for the page's saving overlay.
Future<bool> confirmLeaveAfterAutoSave(
  BuildContext context,
  AutoSaveController controller, {
  ValueChanged<bool>? onFlushingChanged,
}) async {
  while (true) {
    final waits = controller.hasPendingChanges;
    if (waits) onFlushingChanged?.call(true);
    final saved = await controller.flush();
    if (!context.mounted) return false;
    if (waits) onFlushingChanged?.call(false);
    if (saved) return true;

    final error = controller.lastError;
    if (error is AuthExpiredException) {
      await AuthExpiredHandler.handle(context);
      return false;
    }
    debugLog('auto-save failed before leaving: $error');
    final l10n = AppLocalizations.of(context);
    final choice = await showSaveChangesDialog(
      context,
      title: l10n.unsavedChangesTitle,
      body: l10n.autoSaveFailedLeaveBody,
    );
    if (!context.mounted) return false;
    switch (choice) {
      case SaveChangesChoice.save:
        continue;
      case SaveChangesChoice.discard:
        return true;
      case SaveChangesChoice.cancel:
        return false;
    }
  }
}
