import 'package:flutter/material.dart';

import '../../../../core/services/auth_handler.dart';
import '../../../../core/utils/api_error_text.dart';
import '../../../../core/utils/auto_save_controller.dart';
import '../../../../core/utils/debug_log.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'error_dialog.dart';
import 'save_changes_dialog.dart';

// The UI half of [AutoSaveController] — every auto-saving page wires these
// two the same way, so a failure looks identical everywhere:
//
// ```dart
// _autoSave = AutoSaveController(
//   onSave: _persist,
//   onError: (e) => showAutoSaveErrorDialog(context, _autoSave, e,
//       fallback: _l10n.profileSaveFailed),
// );
// ...
// ListenableBuilder(
//   listenable: _autoSave,
//   builder: (context, child) => PopScope(
//     canPop: !_autoSave.hasPendingChanges,
//     onPopInvokedWithResult: (didPop, _) { if (!didPop) _leave(); },
//     child: child!,
//   ),
//   child: ...,
// )
// ```
//
// The `is AuthExpiredException` checks below inspect an error *value*
// handed over by the controller, not a `catch` clause — the page's own
// `onSave` lets every exception propagate so the controller can track the
// failure.

/// [AutoSaveController.onError] handler: session expiry goes to
/// [AuthExpiredHandler]; anything else shows the standard error dialog with
/// a Retry that re-requests the save. Success stays silent by design.
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

/// Back-arrow / system-back handler for an auto-saving page: pushes any
/// pending change first and only then lets the page pop. If that save
/// fails, asks via the shared [showSaveChangesDialog] — Save retries,
/// Don't Save leaves without it, Cancel stays. Returns whether the page
/// should pop now.
///
/// [onFlushingChanged] brackets each wait that actually has a save to push
/// (never the dialog, never a no-op flush), so the page can show its
/// loading overlay only while the user is really waiting on the network.
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
