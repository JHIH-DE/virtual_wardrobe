import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/cms_api.dart';
import '../utils/image_downscale.dart';
import 'cms_scope.dart';
import 'feedback.dart';
import 'image_rights.dart';

/// Pick → shrink if oversized → upload to GCS → hand back the object name.
/// [url] is the current image (signed URL) or null. With [objectName], the
/// image's usage-rights status shows under it.
class ImageUploadField extends StatefulWidget {
  final String label;
  final String? url;
  final ValueChanged<UploadedImage> onUploaded;
  final VoidCallback? onRemoved;
  final double previewHeight;

  /// The current image's object name, for its rights status; null hides it
  /// (no image yet, or an image readers never see).
  final String? objectName;
  final VoidCallback? onRightsChanged;

  const ImageUploadField({
    super.key,
    required this.label,
    required this.url,
    required this.onUploaded,
    this.onRemoved,
    this.previewHeight = 140,
    this.objectName,
    this.onRightsChanged,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final api = CmsScope.read(context);
    setState(() => _uploading = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final file = picked?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      final contentType = CmsApi.contentTypeFor(file.extension);
      if (contentType == null) {
        if (mounted) showMessage(context, '只支援 JPG、PNG、WebP');
        return;
      }
      final prepared = await downscaleForUpload(bytes, contentType);
      final uploaded = await api.uploadImage(
        prepared.bytes,
        prepared.contentType,
      );
      widget.onUploaded(uploaded);
    } catch (e) {
      if (mounted) await showErrorDialog(context, e, title: '圖片上傳失敗');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              height: widget.previewHeight,
              width: widget.previewHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: _uploading
                  ? const Center(child: CircularProgressIndicator())
                  : url == null
                  ? Icon(Icons.image_outlined, color: scheme.outline, size: 40)
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              direction: Axis.vertical,
              children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: const Icon(Icons.upload),
                  label: Text(url == null ? '上傳圖片' : '更換圖片'),
                ),
                if (url != null && widget.onRemoved != null)
                  TextButton.icon(
                    onPressed: _uploading ? null : widget.onRemoved,
                    icon: const Icon(Icons.close),
                    label: const Text('移除'),
                  ),
                if (widget.objectName case final name?)
                  ImageRightsChip(
                    objectName: name,
                    onChanged: widget.onRightsChanged,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// A note on what photo belongs in an empty spot (from an imported draft).
class ImageBrief extends StatelessWidget {
  final String text;
  const ImageBrief(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '建議圖片：$text',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
