import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/image_edit_result.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/buttons/pill_button.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import 'camera_capture_page.dart';

class ImageEditorPage extends StatefulWidget {
  final String? initialPath;
  final bool showAnalysis;

  /// App Bar title override. Garment callers pass the parent page's own
  /// title (`GarmentDetailsPage._title` — "New Clothing" while adding, or
  /// the garment's name while editing an existing one) so this page reads
  /// as a continuation of that flow rather than a generic "Edit". Callers
  /// outside the garment flow (avatar photo, AI model photo) omit this and
  /// keep the generic fallback.
  final String? title;

  /// width/height of the crop preview and the final exported image.
  /// Garment photos default to 1:1 (square product shots); portrait
  /// reference photos (avatar, AI Model's face/body) pass 3/4 instead.
  final double aspectRatio;

  /// Which cutout shape the "Retake" camera opens with. Follows the same
  /// split as [aspectRatio] — portrait reference-photo callers pass
  /// [CameraFrameRatio.portrait], garment callers keep the square default.
  final CameraFrameRatio cameraFrameRatio;

  const ImageEditorPage({
    super.key,
    this.initialPath,
    this.showAnalysis = true,
    this.title,
    this.aspectRatio = 1.0,
    this.cameraFrameRatio = CameraFrameRatio.square,
  });

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  String? _currentPath;
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _previewBoundaryKey = GlobalKey();
  bool _isAnalyzing = false;
  // Synchronous re-entrancy guard covering the whole confirm flow — set
  // before _captureFramedImage()'s await (which runs before _isAnalyzing is
  // raised), so a double-tap during that framing capture can't fire two
  // analyzeGarment() calls or two Navigator.pop()s. See CLAUDE.md "Guarding
  // costly / mutating actions against double-invocation".
  bool _confirming = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
  }

  void _resetImage() {
    setState(() {
      _transformationController.value = Matrix4.identity();
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
        _resetImage();
      });
    }
  }

  Future<void> _handleAlbum() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      setState(() {
        _currentPath = xFile.path;
        _resetImage();
      });
    }
  }

  /// Rasterizes exactly what's currently visible in the crop preview —
  /// i.e. respects whatever pinch-zoom/pan framing the user applied via
  /// [_transformationController] — rather than re-reading and blindly
  /// center-cropping the source file. Its shape follows [widget.aspectRatio]
  /// since it just captures whatever the preview boundary is laid out as.
  /// This also means it works the same way whether [_currentPath] is a
  /// local file or a remote (http) URL: either way, the output is always a
  /// fresh local file.
  Future<String> _captureFramedImage() async {
    final boundary =
        _previewBoundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio * 2;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    final outPath =
        '${Directory.systemTemp.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outPath).writeAsBytes(byteData!.buffer.asUint8List());
    return outPath;
  }

  Future<void> _handleConfirmed() async {
    if (_confirming || _currentPath == null || _isAnalyzing) return;
    setState(() => _confirming = true);
    try {
      final processPath = await _captureFramedImage();
      if (!mounted) return;

      if (widget.showAnalysis) {
        await _analyzeAndFinish(processPath);
      } else {
        Navigator.of(context).pop(ImageEditResult(imagePath: processPath));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  /// Runs the AI analysis and pops with the result. On failure it stays on
  /// this page and asks whether to retry (looping) rather than continuing to
  /// Garment Details with no analysis — a slow first call (cold start) or a
  /// dropped one shouldn't silently leave every field blank.
  Future<void> _analyzeAndFinish(String processPath) async {
    while (mounted) {
      setState(() => _isAnalyzing = true);
      ImageEditResult? done;
      try {
        final result = await GarmentService().analyzeGarment(processPath);
        debugLog('_analyzeAndFinish: ${result.metadata}');
        done = ImageEditResult(
          imagePath: result.processedImagePath ?? processPath,
          analysisData: result.metadata,
          versatility: result.versatility,
        );
      } on AuthExpiredException {
        if (!mounted) return;
        setState(() => _isAnalyzing = false);
        await AuthExpiredHandler.handle(context);
        return;
      } catch (e) {
        debugLog('Analysis failed: $e');
      }

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      if (done != null) {
        Navigator.of(context).pop(done);
        return;
      }
      if (!await _confirmRetryAnalysis()) return;
    }
  }

  Future<bool> _confirmRetryAnalysis() async {
    if (!mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.analysisFailedTitle,
        body: _l10n.analysisFailedBody,
        primaryLabel: _l10n.retry,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    return retry == true;
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: widget.title ?? _l10n.edit,
      onBack: () {
        if (!_isAnalyzing) Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
        ),
        if (_isAnalyzing)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.analyzingClothingEllipsis),
          ),
      ],
    );
  }

  bool get _hasImage => _currentPath != null && _currentPath!.isNotEmpty;

  bool get _showsBottomActionButton => _hasImage && !_isAnalyzing;

  Widget _buildConfirmButton() {
    return BottomActionButton(
      label: _isAnalyzing ? _l10n.analyzingEllipsis : _l10n.confirmed,
      onPressed: (_hasImage && !_isAnalyzing && !_confirming)
          ? _handleConfirmed
          : null,
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
        if (_hasImage && !_isAnalyzing) _buildResetButton(),
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
            onPressed: _isAnalyzing ? () {} : _handleRetake,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PillButton(
            label: Text(_l10n.album, style: AppTextStyle.bold16),
            icon: Image.asset('assets/images/album.png', height: 32),
            onPressed: _isAnalyzing ? () {} : _handleAlbum,
          ),
        ),
      ],
    );
  }
}
