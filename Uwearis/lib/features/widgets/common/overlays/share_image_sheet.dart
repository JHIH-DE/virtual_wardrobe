import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/debug_log.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Bottom sheet that previews a share card and, on tap, rasterizes it to a
/// PNG and hands it to the system share sheet. The one share-a-card flow
/// behind Garment Details / Outfit Details — callers supply the [title], the
/// image URLs to precache, a [cardBuilder] (given the decoded providers, in
/// the same order), and the share [text].
///
/// URLs may be remote (http) signed URLs or local file paths. The card is
/// only captured once every image has decoded, so no blank frames land in
/// the PNG.
Future<void> showShareImageSheet(
  BuildContext context, {
  required String title,
  required List<String> precacheUrls,
  required Widget Function(List<ImageProvider> images) cardBuilder,
  String? text,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ShareImageSheet(
      title: title,
      precacheUrls: precacheUrls,
      cardBuilder: cardBuilder,
      text: text,
    ),
  );
}

class _ShareImageSheet extends StatefulWidget {
  final String title;
  final List<String> precacheUrls;
  final Widget Function(List<ImageProvider>) cardBuilder;
  final String? text;

  const _ShareImageSheet({
    required this.title,
    required this.precacheUrls,
    required this.cardBuilder,
    this.text,
  });

  @override
  State<_ShareImageSheet> createState() => _ShareImageSheetState();
}

class _ShareImageSheetState extends State<_ShareImageSheet> {
  final _boundaryKey = GlobalKey();
  late final List<ImageProvider> _images;
  bool _imageReady = false;
  bool _imageFailed = false;
  bool _sharing = false;
  bool _shareFailed = false;

  ImageProvider _providerFor(String url) {
    final u = url.trim();
    return u.startsWith('http')
        ? CachedNetworkImageProvider(u)
        : FileImage(File(u));
  }

  @override
  void initState() {
    super.initState();
    _images = widget.precacheUrls.map(_providerFor).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precache());
  }

  Future<void> _precache() async {
    try {
      await Future.wait([for (final p in _images) precacheImage(p, context)]);
      if (mounted) setState(() => _imageReady = true);
    } catch (e) {
      debugLog('share sheet: image precache failed: $e');
      if (mounted) setState(() => _imageFailed = true);
    }
  }

  Future<void> _share() async {
    if (_sharing || !_imageReady) return;
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      // ~1080px wide regardless of the preview's on-screen scale.
      final image = await boundary.toImage(
        pixelRatio: 1080 / boundary.size.width,
      );
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/uwearis_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      // iPad needs an anchor rect for the share popover.
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.text,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      debugLog('share failed: $e');
      if (mounted) setState(() => _shareFailed = true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: AppTextStyle.bold18),
            const SizedBox(height: 16),
            if (_imageFailed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  l10n.shareImageUnavailable,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              // Flexible + scaleDown: the fixed-size card shrinks to fit a
              // narrow or short sheet, but the capture is always taken at
              // the card's own logical size (RepaintBoundary ignores the
              // FittedBox transform).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: widget.cardBuilder(_images),
                  ),
                ),
              ),
            if (_shareFailed) ...[
              const SizedBox(height: 12),
              Text(
                l10n.shareFailed,
                style: AppTextStyle.regular13.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_imageReady && !_sharing) ? _share : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnPrimary,
                  disabledBackgroundColor: AppColors.accent.withValues(
                    alpha: 0.5,
                  ),
                  disabledForegroundColor: AppColors.textOnPrimary,
                  minimumSize: const Size(0, 48),
                  elevation: 0,
                  side: const BorderSide(
                    color: AppColors.borderOnDark,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  ),
                ),
                child: _sharing || (!_imageReady && !_imageFailed)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.ios_share, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            l10n.share,
                            style: AppTextStyle.medium16.copyWith(
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
