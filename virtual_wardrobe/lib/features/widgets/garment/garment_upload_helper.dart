import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../data/image_edit_result.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../edit_garment_page.dart';
import '../../camera_capture_page.dart';
import '../../image_editor_page.dart';

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
                  style: AppTextStyle.bold16,
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
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(dialogCtx),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/images/page_arrow_left.png',
                      height: AppDimens.iconSmallSize,
                    ),
                  ),
                  label: Text(l10n.back, style: AppTextStyle.bold16),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
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
    Navigator.pop(dialogContext); // 關閉彈窗

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
      // 1. 跳轉到編輯頁面
      final result = await Navigator.push<ImageEditResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorPage(initialPath: imagePath),
        ),
      );

      // 2. 跳轉到新增頁面
      if (result != null) {
        if (!context.mounted) return;
        final newGarment = await Navigator.push<Garment>(
          context,
          MaterialPageRoute(
            builder: (_) => EditGarmentPage(
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
        }
        onComplete?.call();
      }
    }
  }
}
