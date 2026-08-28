import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../data/image_edit_result.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../pages/camera_capture_page.dart';
import '../../pages/garment_details_page.dart';
import '../../pages/image_editor_page.dart';
import '../common/buttons/close_action_button.dart';
import '../common/overlays/feedback_overlay.dart';

class GarmentUploadHelper {
  static void showAddClothingDialog(
    BuildContext context, {
    VoidCallback? onComplete,
    void Function(Garment)? onAdded,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final l10n = AppLocalizations.of(dialogCtx);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: Container(
            width: 229,
            height: 402,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/add.png',
                  height: AppDimens.iconLargeSize,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.addClothingPrompt,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.bold20,
                ),
                const SizedBox(height: 16),
                _buildDialogOption(
                  dialogCtx,
                  icon: Image.asset(
                    'assets/images/camera.png',
                    height: AppDimens.iconMediumSize,
                  ),
                  label: Text(l10n.camera, style: AppTextStyle.bold16),
                  onTap: () => _onPickImage(
                    context,
                    dialogCtx,
                    ImageSource.camera,
                    onComplete,
                    onAdded,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDialogOption(
                  dialogCtx,
                  icon: Image.asset(
                    'assets/images/album.png',
                    height: AppDimens.iconMediumSize,
                  ),
                  label: Text(l10n.photoAlbum, style: AppTextStyle.bold16),
                  onTap: () => _onPickImage(
                    context,
                    dialogCtx,
                    ImageSource.gallery,
                    onComplete,
                    onAdded,
                  ),
                ),
                const SizedBox(height: 24),
                CloseActionButton(onPressed: () => Navigator.pop(dialogCtx)),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildDialogOption(
    BuildContext context, {
    required Widget icon,
    required Widget label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(children: [label, const Spacer(), icon]),
      ),
    );
  }

  static Future<void> _onPickImage(
    BuildContext context,
    BuildContext dialogContext,
    ImageSource source,
    VoidCallback? onComplete,
    void Function(Garment)? onAdded,
  ) async {
    Navigator.pop(dialogContext); // Close the dialog

    String? imagePath;

    if (source == ImageSource.camera) {
      imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CameraCapturePage()),
      );
    } else {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      imagePath = xFile?.path;
    }

    if (imagePath != null) {
      // 1. Navigate to the edit page
      final result = await Navigator.push<ImageEditResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorPage(
            initialPath: imagePath,
            title: AppLocalizations.of(context).quickActionAddClothing,
          ),
        ),
      );

      // 2. Navigate to the add page
      if (result != null) {
        if (!context.mounted) return;
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
              initialVersatility: result.versatility,
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
    }
  }
}
