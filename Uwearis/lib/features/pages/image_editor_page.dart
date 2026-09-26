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
  /// App bar title — describes which photo is being edited (e.g. "Body
  /// Reference", "Profile Photo"), since this page is shared across several
  /// unrelated photo flows and has no other on-screen label for that.
  final String title;

  final String? initialPath;

  /// width/height of the crop preview and the final exported image.
  /// Garment photos default to 1:1 (square product shots); portrait
  /// reference photos (avatar, AI Model's face/body) pass 3/4 instead.
  final double aspectRatio;

  /// Which cutout shape the "Retake" camera opens with. Follows the same
  /// split as [aspectRatio] — portrait reference-photo callers pass
  /// [CameraFrameRatio.portrait], garment callers keep the square default.
  final CameraFrameRatio cameraFrameRatio;

  /// Confirm stays unavailable until the user has actually changed
  /// something (swapped the source photo via Retake/Album, or adjusted the
  /// pinch-zoom/pan framing) — set this for callers that reopen an
  /// *already-saved* photo to tweak it (avatar/body/face reference photos),
  /// where confirming with zero changes would just re-upload an identical
  /// copy for no reason. Leave false (default) for a
  /// freshly-picked photo with no "unmodified" baseline to compare against
  /// (the New Clothing / Match a Look flows) — there, confirming as-is with
  /// the default framing is the normal, expected action.
  final bool requireChangeToConfirm;

  /// Called at most once, only when [initialPath] is a URL and fails to
  /// precache/load — mirrors [RefreshableNetworkImage]'s "self-heal a
  /// stale signed URL" contract. Return a fresh URL to retry with, or
  /// null/empty to give up. Only relevant to a caller that hands this page
  /// a signed URL directly (account_page.dart's avatar flow does) rather
  /// than pre-downloading it to a local file first — a caller that
  /// pre-downloads (my_virtual_model_page.dart's face/body reference photos,
  /// via `downloadReferencePhotoOriginal`) always passes a local path here
  /// instead, so this branch never runs for it; that pre-download is what
  /// keeps the refreshed URL in sync with the page's own longer-lived state
  /// (e.g. `profileProvider`) instead of it living only inside whichever
  /// widget happened to trigger the refresh.
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
  // Synchronous re-entrancy guard covering the whole confirm flow — set
  // before _captureFramedImage()'s await, so a double-tap during that
  // framing capture can't fire two Navigator.pop()s. See CLAUDE.md
  // "Guarding costly / mutating actions against double-invocation".
  bool _confirming = false;
  // True once Retake/Album has swapped in a different photo than
  // widget.initialPath — the other half of widget.requireChangeToConfirm's
  // "did anything actually change" check (see _hasChanges).
  bool _sourceReplaced = false;
  // True once the pinch-zoom/pan framing differs from identity — the other
  // half of widget.requireChangeToConfirm's "did anything actually change"
  // check (see _hasChanges). Tracked via a listener since InteractiveViewer
  // updates _transformationController directly, outside any handler here.
  bool _transformChanged = false;

  // True only while the user's fingers are actually on the InteractiveViewer
  // (pinch/pan in progress) — gates the rule-of-thirds grid (see
  // _buildImagePreview) so it only appears as a framing aid during zoom
  // mode, not sitting on the photo the rest of the time.
  bool _interacting = false;

  // True once _currentPath's bytes are decoded enough to actually paint the
  // preview — gates Confirm (see _canConfirm) purely so the user can't tap
  // it while still staring at the loading spinner over a photo they
  // haven't actually seen framed yet. _captureFramedImage itself now
  // re-decodes the source fresh and doesn't depend on this — see its own
  // doc for why (it used to, via a screenshot of this preview, which is
  // also what this flag's staleness protection below was originally
  // guarding). Reset to false whenever _currentPath changes (initState,
  // Retake, Album).
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

  /// [allowRefresh] caps the self-heal below to one attempt per call to
  /// [_precacheCurrentImage] — the retry itself passes false, so a
  /// [widget.onRefreshUrl] that keeps handing back a still-broken URL can't
  /// loop forever.
  Future<void> _tryPrecache(String path, {required bool allowRefresh}) async {
    final isHttp = path.startsWith('http');
    final provider = isHttp
        ? NetworkImage(path) as ImageProvider
        : FileImage(File(path));
    try {
      await precacheImage(provider, context);
    } catch (e) {
      // A genuinely broken file still shows via _buildImageContent's own
      // error state — this is only about decode-ahead timing, not
      // validating the file, so a failure here isn't itself an error case.
      debugLog('Failed to precache image: $e');
      // Likely a stale signed URL: whatever screen linked here already
      // self-heals the same URL via RefreshableNetworkImage, but that
      // refresh lives in that widget's own state and never reaches
      // widget.initialPath — see onRefreshUrl's own doc.
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
          // The underlying reference photo is genuinely gone (not just a
          // stale signed URL) — surface this instead of silently leaving
          // the user staring at _buildImageContent's broken-image icon with
          // no explanation of what to do next (retake/pick a new photo).
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
    // path == _currentPath: a Retake/Album swap mid-precache must not let
    // this stale completion mark the *new* current path ready.
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

  /// Whether [widget.requireChangeToConfirm] should currently block confirm
  /// — the source photo was swapped, or the crop framing was adjusted.
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

  /// Crops exactly what's currently visible in the crop preview — i.e.
  /// respects whatever pinch-zoom/pan framing the user applied via
  /// [_transformationController] — directly out of the *original* source
  /// bytes, not a screenshot of the on-screen preview.
  ///
  /// An earlier version used `RenderRepaintBoundary.toImage()` to rasterize
  /// the live preview widget instead. That's simpler, but reads back
  /// whatever the GPU has actually composited for the *on-screen* preview
  /// box — for a source photo much higher-resolution than that box (a
  /// shared/downloaded product shot easily 1000px+ taller than the
  /// preview), minifying it down for display is lossy in a way that shows
  /// up as visible moiré/artifacting on fine repeating patterns (e.g.
  /// plaid) in the *saved* photo, not just the live preview — and doesn't
  /// go away by waiting longer or asking for a higher-quality on-screen
  /// filter (tried both; see git history). Reading the original bytes and
  /// cropping+resampling them directly, once, off-screen, sidesteps both:
  /// there's no render-timing race to lose to, and the resample only ever
  /// has to happen once at whatever quality we ask for, not every frame.
  Future<String> _captureFramedImage() async {
    final path = _currentPath!;
    final Uint8List sourceBytes = path.startsWith('http')
        ? (await http.get(Uri.parse(path)).timeout(const Duration(seconds: 30)))
              .bodyBytes
        : await File(path).readAsBytes();

    // Decoded, cropped, and resized entirely off the GPU, via package:image
    // (plain CPU pixel buffers) rather than dart:ui's Canvas/
    // PictureRecorder/Image.toImage(). An earlier version used the latter,
    // which — despite not touching the live preview widget at all — still
    // ultimately rasterizes through the engine's real GPU pipeline
    // (Impeller) on a real device, the same class of "read back before the
    // raster thread actually finished" race this whole rewrite was meant
    // to close; a plain `flutter test` run can't catch that gap since its
    // software Skia backend never races. package:image never touches a
    // GPU at all, so there's no such window to lose to.
    // package:image has no HEIF/HEIC decoder — iPhone's default camera
    // format since iOS 11, which Android never transcodes when a
    // shared/synced photo keeps its original container, so this is a real
    // gallery pick, not just an edge case. Fall back to dart:ui's own
    // codec, which defers to the OS's native image decoder (both Android
    // and iOS can decode HEIF at the platform level) before giving up.
    final decoded =
        img.decodeImage(sourceBytes) ??
        await _decodeViaPlatformCodec(sourceBytes);
    if (decoded == null) {
      throw StateError('Could not decode image at $path');
    }
    // _handleConfirmed already re-checks mounted with whatever this
    // returns before touching it — an empty path here is never read.
    if (!mounted) return '';

    // The preview box's own on-screen size — needed to reverse the same
    // BoxFit.contain fit + InteractiveViewer pan/zoom the box itself uses,
    // so the crop matches what the user actually framed.
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
    // Only actually resizes when outputSize is smaller (computeOutputSize
    // never upscales) — copyResize with the crop's own size would be a
    // needless full re-sample of an already-correctly-sized image.
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

  /// Fallback for [_captureFramedImage] when `package:image` can't decode
  /// the source (see that call site's comment) — decodes via dart:ui's own
  /// codec instead, then hands the raw pixels back as a `package:image`
  /// [img.Image] so the crop/resize/encode pipeline above stays unchanged.
  /// Returns null on failure, same as `img.decodeImage`.
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
      // Reachable if _captureFramedImage's decode fails even after the
      // platform-codec fallback (a genuinely corrupt file, or a format
      // neither decoder supports) — was an uncaught StateError before this,
      // crashing the whole app instead of letting the user just pick a
      // different photo.
      if (!mounted) return;
      debugLog('_handleConfirmed: could not process image: $e');
      showErrorDialog(context, message: _l10n.photoProcessingFailed);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: widget.title,
      onBack: () => Navigator.pop(context),
    );
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
              // Inside the clip, so capturing this boundary doesn't bake in
              // the rounded corners — just the framed photo content.
              child: RepaintBoundary(
                key: _previewBoundaryKey,
                child: _buildImageContent(),
              ),
            ),
          ),
        ),
        if (_hasImage && _imageReady && _interacting)
          Positioned.fill(
            // Rule-of-thirds framing guide, fixed to the preview box rather
            // than the pinch-zoomed image underneath — outside the
            // RepaintBoundary above, so it never ends up baked into the
            // captured/cropped photo. Only shown while actively
            // pinching/panning (see _interacting), like a camera's zoom grid.
            // The dark scrim behind the grid lines is what's being framed —
            // dimming it makes the white lines read clearly against any
            // photo, bright or dark.
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                child: const Stack(
                  // Both layers need to fill the framed box exactly — a
                  // plain Stack would shrink-wrap the sizeless CustomPaint.
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
            // Opaque, not just an overlaid spinner — masks the image
            // underneath until precache confirms it's fully decoded, so the
            // user (and _captureFramedImage, once Confirm unlocks) never
            // sees/captures a still-loading frame.
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
        // opaque so the whole pill (padding + the gap between label and
        // icon) is tappable, not just the glyphs.
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

/// Static rule-of-thirds crop-guide grid drawn over the preview box —
/// evenly-spaced vertical and horizontal lines, purely a framing aid
/// (never baked into the captured photo — see its call site). Always 3
/// columns; the row count is derived from the box's own aspect ratio so
/// every cell stays square (3×3 for a square preview, 3×4 for a 3:4
/// portrait one) instead of stretching into rectangles.
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

/// The source-image pixel rect [_ImageEditorPageState._captureFramedImage]
/// crops — a pure function (no BuildContext/State) so this geometry is
/// unit-testable on its own, since getting it wrong is easy and silent
/// (the app would just save the wrong region, not crash). Reverses, in
/// order: [transform] ([InteractiveViewer]'s own — it maps its child, which
/// fills [boxSize], to the viewport, also [boxSize]), then the
/// [BoxFit.contain] fit of [imageSize] within that same [boxSize] the
/// preview's `Image` widget applies. Clamped to the image's own bounds.
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

/// Scales [cropSize] down (never up) so neither side exceeds
/// [maxDimension] — a barely-zoomed crop of a large shared photo can still
/// be close to its full source resolution, and nothing downstream
/// (display, AI analysis) needs more than this.
@visibleForTesting
Size computeOutputSize(Size cropSize, {double maxDimension = 1600}) {
  final scale = math.min(
    1.0,
    maxDimension / math.max(cropSize.width, cropSize.height),
  );
  return cropSize * scale;
}
