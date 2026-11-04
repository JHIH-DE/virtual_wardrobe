import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/auth_handler.dart';
import '../../../core/services/garment_service.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/garment.dart';
import '../../../data/image_edit_result.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../pages/wardrobe/garment_details_page.dart';
import '../common/overlays/ai_consent_dialog.dart';
import '../common/overlays/app_dialog.dart';
import '../common/overlays/feedback_overlay.dart';
import '../common/overlays/loading_overlay.dart';
import '../common/overlays/photo_source_dialog.dart';

class GarmentUploadHelper {
  static void showAddClothingDialog(
    BuildContext context, {
    VoidCallback? onComplete,
    void Function(Garment)? onAdded,
  }) {
    _pickAndStartAddClothingFlow(
      context,
      onComplete: onComplete,
      onAdded: onAdded,
    );
  }

  static Future<void> _pickAndStartAddClothingFlow(
    BuildContext context, {
    VoidCallback? onComplete,
    void Function(Garment)? onAdded,
  }) async {
    final l10n = AppLocalizations.of(context);
    final imagePath = await showPhotoSourceDialog(
      context,
      title: l10n.quickActionAddClothing,
    );
    if (imagePath == null || !context.mounted) return;
    await startAddClothingFlow(
      context,
      imagePath: imagePath,
      onComplete: onComplete,
      onAdded: onAdded,
    );
  }

  /// Shared by camera/album ([showAddClothingDialog]) and photos shared in
  /// from another app (`SharedMediaHandler`).
  static Future<void> startAddClothingFlow(
    BuildContext context, {
    required String imagePath,
    VoidCallback? onComplete,
    void Function(Garment)? onAdded,
  }) async {
    final result = await analyzePhoto(context, imagePath);
    if (result == null || !context.mounted) return;

    final newGarment = await Navigator.push<Garment>(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentDetailsPage(
          initialGarment: Garment(
            name: '',
            category: GarmentCategory.top,
            subCategory: '',
            uploadUrl: '',
            objectName: '',
            imageUrl: result.imagePath,
          ),
          initialAnalysisData: result.analysisData,
        ),
      ),
    );
    if (newGarment != null) {
      onAdded?.call(newGarment);
      if (context.mounted) {
        showFeedbackOverlay(
          context,
          message: AppLocalizations.of(context).clothingAdded,
        );
      }
    }
    onComplete?.call();
  }

  /// Background removal + AI metadata, with retry-or-cancel on failure. No
  /// manual crop step: the backend crops to the subject itself. Returns null
  /// on cancel or auth expiry (already handled here).
  static Future<ImageEditResult?> analyzePhoto(
    BuildContext context,
    String imagePath,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Captured up front: the overlay must be popped from the navigator
    // showDialog pushed it onto, and `context` may be stale after the await.
    final navigator = Navigator.of(context, rootNavigator: true);
    if (!await ensureAiConsent(context)) return null;

    while (true) {
      if (!context.mounted) return null;
      // The request can't be aborted: Cancel (or system back) closes the
      // overlay and this attempt's reply is ignored when it lands.
      var settled = false;
      final cancelled = Completer<AnalyzeGarmentResult?>();
      void cancel() {
        if (settled) return;
        settled = true;
        navigator.pop();
        cancelled.complete(null);
      }

      // Pops the overlay unless Cancel already did; false once cancelled.
      bool settle() {
        if (settled) return false;
        settled = true;
        navigator.pop();
        return true;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        useSafeArea: false,
        builder: (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) cancel();
          },
          child: LoadingOverlay(
            label: l10n.analyzingGarmentEllipsis,
            actionLabel: l10n.cancel,
            onAction: cancel,
          ),
        ),
      );
      try {
        final result = await Future.any([
          GarmentService().analyzeGarment(imagePath),
          cancelled.future,
        ]);
        if (result == null || !settle()) return null;
        return ImageEditResult(
          imagePath: result.processedImagePath ?? imagePath,
          analysisData: result.metadata,
        );
      } on AuthExpiredException {
        if (!settle()) return null;
        if (context.mounted) await AuthExpiredHandler.handle(context);
        return null;
      } catch (e) {
        if (!settle()) return null;
        debugLog('GarmentUploadHelper.analyzePhoto: $e');
        if (!context.mounted) return null;
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AppDialog(
            title: l10n.analysisFailedTitle,
            body: l10n.analysisFailedBody,
            primaryLabel: l10n.retry,
            onPrimary: () => Navigator.pop(ctx, true),
            secondaryLabel: l10n.cancel,
            onSecondary: () => Navigator.pop(ctx, false),
          ),
        );
        if (retry != true || !context.mounted) return null;
      }
    }
  }
}
