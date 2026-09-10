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
import '../common/overlays/app_dialog.dart';
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
        return AppDialog(
          title: l10n.quickActionAddClothing,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogOption(
                icon: Image.asset(
                  'assets/images/camera.png',
                  height: AppDimens.iconMediumSize,
                ),
                label: Text(l10n.takePhotoLabel, style: AppTextStyle.bold16),
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
                icon: Image.asset(
                  'assets/images/album.png',
                  height: AppDimens.iconMediumSize,
                ),
                label: Text(
                  l10n.chooseFromAlbumLabel,
                  style: AppTextStyle.bold16,
                ),
                onTap: () => _onPickImage(
                  context,
                  dialogCtx,
                  ImageSource.gallery,
                  onComplete,
                  onAdded,
                ),
              ),
            ],
          ),
          primaryLabel: l10n.cancel,
          primaryIsTextButton: true,
          onPrimary: () => Navigator.pop(dialogCtx),
        );
      },
    );
  }

  static Widget _buildDialogOption({
    required Widget icon,
    required Widget label,
    required VoidCallback onTap,
  }) {
    // Shadow on a plain container; the fill + ink on a Material inside it,
    // so InkWell's pressed highlight actually shows (an opaque Container on
    // top of the ink would hide it).
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
          BoxShadow(
            color: AppColors.shadowResting,
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: AppColors.pressedOverlay,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 14),
                  // scaleDown so a longer label (or wider glyph metrics on
                  // iOS's bundled font) shrinks to fit rather than
                  // overflowing the row.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: label,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      if (!context.mounted) return;
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
