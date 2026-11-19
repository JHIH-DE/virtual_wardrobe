import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/debug_log.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../pages/common/camera_capture_page.dart';
import 'app_dialog.dart';
import 'dialog_option_card.dart';
import 'error_dialog.dart';

/// Camera / album picker dialog; returns the photo's local path, or null if
/// cancelled at any step or the album couldn't be opened (which says so).
/// [subtitle] replaces the generic prompt line.
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
        dismiss: AppDialogDismiss.cancel,
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
  try {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    return xFile?.path;
  } on PlatformException catch (e) {
    // The plugin's documented failures: photo access denied, already open,
    // an unreadable image. Anything else is a bug and propagates.
    debugLog('showPhotoSourceDialog album pick failed: ${e.code}');
    if (context.mounted) {
      showErrorDialog(
        context,
        message: AppLocalizations.of(context).photoPickFailed,
      );
    }
    return null;
  }
}
