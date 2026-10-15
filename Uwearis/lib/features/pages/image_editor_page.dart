import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/debug_log.dart';
import '../../data/image_edit_result.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/buttons/pill_button.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/error_dialog.dart';
import 'camera_capture_page.dart';

class ImageEditorPage extends StatefulWidget {
  /// Which photo is being edited (e.g. "Profile Photo") — the page has no
  /// other label for it.
  final String title;

  final String? initialPath;

  /// Width/height of the crop preview and the exported image.
  final double aspectRatio;

  /// Cutout shape the Retake camera opens with.
  final CameraFrameRatio cameraFrameRatio;

  /// Keeps Confirm unavailable until the photo or framing changes — for
  /// reopening an already-saved photo, where an unchanged confirm would just
  /// re-upload an identical copy.
  final bool requireChangeToConfirm;

  /// Called at most once when [initialPath] is a URL that fails to load
  /// (likely a stale signed URL). Return a fresh URL, or null/empty to give up.
  final Future<String?> Function()? onRefreshUrl;

  const ImageEditorPage({
    super.key,
    required this.title,
    this.initialPath,
    this.aspectRatio = 1.0,
    this.cameraFrameRatio = CameraFrameRatio.square,
    this.requireChangeToConfirm = false,
    this.onRefreshUrl,
  });

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  String? _currentPath;
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _previewBoundaryKey = GlobalKey();
  bool _confirming = false;
  bool _sourceReplaced = false;
  // Tracked via a listener: InteractiveViewer updates the controller
  // directly, outside any handler here.
  bool _transformChanged = false;

  // Pinch/pan in progress — shows the rule-of-thirds grid.
  bool _interacting = false;

  // Gates Confirm so it can't be tapped before the user has seen the photo.
  bool _imageReady = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _transformationController.addListener(_onTransformChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _precacheCurrentImage(),
    );
  }

  Future<void> _precacheCurrentImage() async {
    final path = _currentPath;
    if (path == null || path.isEmpty) return;
    await _tryPrecache(path, allowRefresh: true);
  }

  /// [allowRefresh] caps the URL refresh to one attempt, so an
  /// [ImageEditorPage.onRefreshUrl] that keeps returning a broken URL can't
  /// loop forever.
  Future<void> _tryPrecache(String path, {required bool allowRefresh}) async {
    final isHttp = path.startsWith('http');
    final provider = isHttp
        ? NetworkImage(path) as ImageProvider
        : FileImage(File(path));
    try {
      await precacheImage(provider, context);
    } catch (e) {
      // Not an error case by itself — a broken file still shows
      // _buildImageContent's error state.
      debugLog('Failed to precache image: $e');
      if (isHttp &&
          allowRefresh &&
          widget.onRefreshUrl != null &&
          mounted &&
          path == _currentPath) {
        String? fresh;
        try {
          fresh = await widget.onRefreshUrl!();
        } on AuthExpiredException {
          if (mounted) await AuthExpiredHandler.handle(context);
          return;
        } catch (e2) {
          debugLog('Failed to refresh image URL: $e2');
          // The photo itself is gone, not just a stale URL — explain rather
          // than leave a bare broken-image icon.
          if (mounted) {
            showErrorDialog(
              context,
              message: apiErrorMessage(
                _l10n,
                e2,
                fallback: _l10n.photoProcessingFailed,
              ),
            );
          }
        }
        if (mounted &&
            fresh != null &&
            fresh.isNotEmpty &&
            fresh != path &&
            path == _currentPath) {
          setState(() => _currentPath = fresh);
          await _tryPrecache(fresh, allowRefresh: false);
          return;
        }
      }
    }
    // A Retake/Album swap mid-precache must not mark the new path ready.
    if (mounted && path == _currentPath) setState(() => _imageReady = true);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final changed = _transformationController.value != Matrix4.identity();
    if (changed != _transformChanged) {
      setState(() => _transformChanged = changed);
    }
  }

  bool get _hasChanges => _sourceReplaced || _transformChanged;

  void _resetImage() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _transformChanged = false;
    });
  }

  Future<void> _handleRetake() async {
    final newPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CameraCapturePage(initialRatio: widget.cameraFrameRatio),
      ),
    );
    if (newPath != null) {
      setState(() {
        _currentPath = newPath;
        _sourceReplaced = true;
        _imageReady = false;
        _resetImage();
      });
      _precacheCurrentImage();
    }
  }

  Future<void> _handleAlbum() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      setState(() {
        _currentPath = xFile.path;
        _sourceReplaced = true;
        _imageReady = false;
        _resetImage();
      });
      _precacheCurrentImage();
    }
  }

  /// Crops the user's current framing out of the original source bytes.
  /// Not a screenshot of the preview: minifying a large photo for display
  /// produces moiré on fine patterns (e.g. plaid) in the saved image.
  Future<String> _captureFramedImage() async {
    final path = _currentPath!;
    final Uint8List sourceBytes = path.startsWith('http')
        ? (await http.get(Uri.parse(path)).timeout(const Duration(seconds: 30)))
              .bodyBytes
        : await File(path).readAsBytes();

    // package:image (CPU only): dart:ui's Canvas/toImage rasterizes on the
    // GPU and can read back before the raster thread finishes on a device
    // (flutter test's software backend never shows it).
    // package:image can't decode HEIF/HEIC, so fall back to the platform
    // codec, which can.
    final decoded =
        img.decodeImage(sourceBytes) ??
        await _decodeViaPlatformCodec(sourceBytes);
    if (decoded == null) {
      throw StateError('Could not decode image at $path');
    }
    // _handleConfirmed re-checks mounted, so this empty path is never read.
    if (!mounted) return '';

    final boxSize =
        (_previewBoundaryKey.currentContext!.findRenderObject() as RenderBox)
            .size;
    final imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());

    final cropRect = computeCropRect(
      boxSize: boxSize,
      imageSize: imageSize,
      transform: _transformationController.value,
    );
    final outputSize = computeOutputSize(cropRect.size);

    final cropped = img.copyCrop(
      decoded,
      x: cropRect.left.round(),
      y: cropRect.top.round(),
      width: cropRect.width.round(),
      height: cropRect.height.round(),
    );
    final resized = outputSize.width.round() == cropped.width
        ? cropped
        : img.copyResize(
            cropped,
            width: outputSize.width.round(),
            height: outputSize.height.round(),
            interpolation: img.Interpolation.cubic,
          );

    final outPath =
        '${Directory.systemTemp.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outPath).writeAsBytes(img.encodePng(resized));
    return outPath;
  }

  /// Decodes via the platform codec into an [img.Image]; null on failure,
  /// like `img.decodeImage`.
  Future<img.Image?> _decodeViaPlatformCodec(Uint8List bytes) async {
    ui.Codec codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
    } catch (e) {
      debugLog('_decodeViaPlatformCodec: could not decode: $e');
      return null;
    }
    final frame = await codec.getNextFrame();
    codec.dispose();
    try {
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;
      return img.Image.fromBytes(
        width: frame.image.width,
        height: frame.image.height,
        bytes: byteData.buffer,
        bytesOffset: byteData.offsetInBytes,
        order: img.ChannelOrder.rgba,
      );
    } finally {
      frame.image.dispose();
    }
  }

  Future<void> _handleConfirmed() async {
    if (_confirming || _currentPath == null) return;
    setState(() => _confirming = true);
    try {
      final processPath = await _captureFramedImage();
      if (!mounted) return;
      Navigator.of(context).pop(ImageEditResult(imagePath: processPath));
    } catch (e) {
      // E.g. a file neither decoder can read — let the user pick another.
      if (!mounted) return;
      debugLog('_handleConfirmed: could not process image: $e');
      showErrorDialog(context, message: _l10n.photoProcessingFailed);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildConfirmButton(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildImagePreview(),
            const SizedBox(height: 24),
            _buildPinchHint(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            SizedBox(
              height: _showsBottomActionButton
                  ? AppDimens.bottomActionBtnClearance
                  : 0,
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasImage => _currentPath != null && _currentPath!.isNotEmpty;

  bool get _canConfirm =>
      _hasImage &&
      _imageReady &&
      !_confirming &&
      (!widget.requireChangeToConfirm || _hasChanges);

  bool get _showsBottomActionButton => _canConfirm;

  Widget _buildConfirmButton() {
    return BottomActionButton(
      label: _l10n.confirm,
      onPressed: _canConfirm ? _handleConfirmed : null,
      leading: Image.asset(
        'assets/images/ai_process.png',
        height: AppDimens.iconSmallSize,
        color: AppColors.textOnPrimary,
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowResting,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              // Keyed only to read the preview box's size for the crop.
              child: RepaintBoundary(
                key: _previewBoundaryKey,
                child: _buildImageContent(),
              ),
            ),
          ),
        ),
        if (_hasImage && _imageReady && _interacting)
          Positioned.fill(
            // The scrim keeps the white grid lines readable on any photo.
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                child: const Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: AppColors.scrimMedium),
                    CustomPaint(painter: _RuleOfThirdsGridPainter()),
                  ],
                ),
              ),
            ),
          ),
        if (_hasImage && !_imageReady)
          Positioned.fill(
            // Opaque: hides a half-decoded frame until precache finishes.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              child: ColoredBox(
                color: AppColors.surface,
                child: const Center(child: AppSpinner(size: 28)),
              ),
            ),
          ),
        if (_hasImage) _buildResetButton(),
      ],
    );
  }

  Widget _buildImageContent() {
    if (!_hasImage) {
      return const Center(
        child: Icon(Icons.image, size: 50, color: AppColors.icon),
      );
    }
    final image = _currentPath!.startsWith('http')
        ? Image.network(
            _currentPath!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image, size: 50, color: AppColors.icon),
            ),
          )
        : Image.file(File(_currentPath!), fit: BoxFit.contain);
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      onInteractionStart: (_) => setState(() => _interacting = true),
      onInteractionEnd: (_) => setState(() => _interacting = false),
      child: image,
    );
  }

  Widget _buildResetButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _resetImage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.scrimBackdrop,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Text(
                _l10n.reset,
                style: AppTextStyle.bold16.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/reset.png',
                height: AppDimens.iconSmallSize,
                color: AppColors.textOnPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinchHint() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          child: Image.asset('assets/images/pinch.png', height: 54),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(_l10n.pinchToZoomHint, style: AppTextStyle.bold16),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: PillButton(
            label: Text(_l10n.retake, style: AppTextStyle.bold16),
            icon: Image.asset('assets/images/camera.png', height: 32),
            onPressed: _handleRetake,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PillButton(
            label: Text(_l10n.album, style: AppTextStyle.bold16),
            icon: Image.asset('assets/images/album.png', height: 32),
            onPressed: _handleAlbum,
          ),
        ),
      ],
    );
  }
}

/// Rule-of-thirds grid: 3 columns, rows derived from the aspect ratio so
/// cells stay square (3×3 for 1:1, 3×4 for 3:4).
class _RuleOfThirdsGridPainter extends CustomPainter {
  const _RuleOfThirdsGridPainter();

  static const _columns = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceTranslucent
      ..strokeWidth = 2;
    final rows = (_columns * size.height / size.width).round();
    for (var i = 1; i < _columns; i++) {
      final x = size.width * i / _columns;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RuleOfThirdsGridPainter oldDelegate) => false;
}

/// Source-image pixel rect for the visible preview: reverses the
/// [InteractiveViewer] [transform], then the [BoxFit.contain] fit of
/// [imageSize] in [boxSize]. Clamped to the image bounds.
@visibleForTesting
Rect computeCropRect({
  required Size boxSize,
  required Size imageSize,
  required Matrix4 transform,
}) {
  final baseScale = math.min(
    boxSize.width / imageSize.width,
    boxSize.height / imageSize.height,
  );
  final fittedOffset = Offset(
    (boxSize.width - imageSize.width * baseScale) / 2,
    (boxSize.height - imageSize.height * baseScale) / 2,
  );

  final inverseTransform = Matrix4.inverted(transform);
  Offset toImagePoint(Offset viewportPoint) {
    final childPoint = MatrixUtils.transformPoint(
      inverseTransform,
      viewportPoint,
    );
    return (childPoint - fittedOffset) / baseScale;
  }

  return Rect.fromPoints(
    toImagePoint(Offset.zero),
    toImagePoint(Offset(boxSize.width, boxSize.height)),
  ).intersect(Rect.fromLTWH(0, 0, imageSize.width, imageSize.height));
}

/// Scales [cropSize] down (never up) so neither side exceeds [maxDimension].
@visibleForTesting
Size computeOutputSize(Size cropSize, {double maxDimension = 1600}) {
  final scale = math.min(
    1.0,
    maxDimension / math.max(cropSize.width, cropSize.height),
  );
  return cropSize * scale;
}
