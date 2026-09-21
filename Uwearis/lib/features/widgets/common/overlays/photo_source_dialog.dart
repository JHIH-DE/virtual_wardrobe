import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../pages/camera_capture_page.dart';
import 'app_dialog.dart';
import 'dialog_option_card.dart';

/// Shows a "Take Photo / Choose from Album" dialog and returns the picked
/// photo's local path, or null if the user cancels at any step (the dialog
/// itself, or the camera/gallery picker it opens). Shared by every flow that
/// needs one photo from either source: [GarmentUploadHelper]'s new-garment
/// flow and Match a Look's reference photo.
Future<String?> showPhotoSourceDialog(
  BuildContext context, {
  required String title,
}) async {
  final source = await showDialog<ImageSource>(
    context: context,
    builder: (dialogCtx) {
      final l10n = AppLocalizations.of(dialogCtx);
      return AppDialog(
        title: title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.photoSourceDialogSubtitle,
              textAlign: TextAlign.center,
              style: AppTextStyle.medium16,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DialogOptionCard(
                    variant: DialogOptionCardVariant.square,
                    icon: Image.asset('assets/images/camera.png', height: 32),
                    label: Text(l10n.takePhotoLabel, style: AppTextStyle.bold16),
                    onTap: () => Navigator.pop(dialogCtx, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DialogOptionCard(
                    variant: DialogOptionCardVariant.square,
                    icon: Image.asset('assets/images/album.png', height: 32),
                    label: Text(
                      l10n.chooseFromAlbumLabel,
                      style: AppTextStyle.bold16,
                    ),
                    onTap: () => Navigator.pop(dialogCtx, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
        primaryLabel: l10n.cancel,
        primaryIsTextButton: true,
        onPrimary: () => Navigator.pop(dialogCtx),
      );
    },
  );
  if (source == null || !context.mounted) return null;

  if (source == ImageSource.camera) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );
  }
  final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
  return xFile?.path;
}
