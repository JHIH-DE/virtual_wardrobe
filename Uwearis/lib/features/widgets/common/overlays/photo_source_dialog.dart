import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../pages/camera_capture_page.dart';
import 'app_dialog.dart';
import 'dialog_option_card.dart';

/// Camera / album picker dialog; returns the photo's local path, or null if
/// cancelled at any step. [subtitle] replaces the generic prompt line.
Future<String?> showPhotoSourceDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  CameraFrameRatio cameraFrameRatio = CameraFrameRatio.square,
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
              subtitle ?? l10n.photoSourceDialogSubtitle,
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
                    label: Text(
                      l10n.takePhotoLabel,
                      style: AppTextStyle.bold16,
                    ),
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
      MaterialPageRoute(
        builder: (_) => CameraCapturePage(initialRatio: cameraFrameRatio),
      ),
    );
  }
  final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
  return xFile?.path;
}
