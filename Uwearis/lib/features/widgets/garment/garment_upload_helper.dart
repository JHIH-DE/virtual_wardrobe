import 'package:flutter/material.dart';

import '../../../core/services/auth_handler.dart';
import '../../../core/services/garment_service.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/garment.dart';
import '../../../data/image_edit_result.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../pages/garment_details_page.dart';
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

  /// The analyze → add-garment continuation shared by every source of a new
  /// clothing photo — camera/album (via [showAddClothingDialog] above) and
  /// a photo shared in from another app (`SharedMediaHandler`).
  static Future<void> startAddClothingFlow(
    BuildContext context, {
    required String imagePath,
    VoidCallback? onComplete,
    void Function(Garment)? onAdded,
  }) async {
    // 1. Analyze the photo (background removal + metadata) — the backend
    // crops to the subject itself now, so there's no manual crop step here
    // any more; see analyzePhoto's own doc for why.
    final result = await analyzePhoto(context, imagePath);
    if (result == null || !context.mounted) return;

    // 2. Navigate to the add page
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

  /// Runs [GarmentService.analyzeGarment] on [imagePath] (background
  /// removal + AI metadata) behind a modal loading overlay, offering
  /// retry-or-cancel on failure. Called by [startAddClothingFlow] above — a
  /// manual crop step used to run before this call (`ImageEditorPage`), but
  /// the backend's own auto-crop-to-subject (`_finalize_garment_image` in
  /// virtual-wardrobe-backend) makes that unnecessary now. Returns null if
  /// the user cancels the retry prompt, or on an unrecoverable auth expiry
  /// (already handled here).
  static Future<ImageEditResult?> analyzePhoto(
    BuildContext context,
    String imagePath,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Captured up front: `context` can't be trusted for navigation after
    // the network round-trip below, and the loading overlay must be popped
    // from the same navigator that showDialog pushes it onto.
    final navigator = Navigator.of(context, rootNavigator: true);

    while (true) {
      if (!context.mounted) return null;
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        useSafeArea: false,
        builder: (_) => LoadingOverlay(label: l10n.analyzingClothingEllipsis),
      );
      try {
        final result = await GarmentService().analyzeGarment(imagePath);
        navigator.pop(); // close loading indicator
        return ImageEditResult(
          imagePath: result.processedImagePath ?? imagePath,
          analysisData: result.metadata,
        );
      } on AuthExpiredException {
        navigator.pop(); // close loading indicator
        if (context.mounted) await AuthExpiredHandler.handle(context);
        return null;
      } catch (e) {
        navigator.pop(); // close loading indicator
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
        // loop and retry
      }
    }
  }
}
