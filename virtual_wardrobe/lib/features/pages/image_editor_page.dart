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
import 'camera_capture_page.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/buttons/pill_button.dart';

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

  const ImageEditorPage({
    super.key,
    this.initialPath,
    this.showAnalysis = true,
    this.title,
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
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
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

  /// Rasterizes exactly what's currently visible in the square preview —
  /// i.e. respects whatever pinch-zoom/pan framing the user applied via
  /// [_transformationController] — rather than re-reading and blindly
  /// center-cropping the source file. This also means it works the same
  /// way whether [_currentPath] is a local file or a remote (http) URL:
  /// either way, the output is always a fresh local file.
  Future<String> _captureSquareImage() async {
    final boundary =
        _previewBoundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio * 2;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    final outPath =
        '${Directory.systemTemp.path}/sq_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outPath).writeAsBytes(byteData!.buffer.asUint8List());
    return outPath;
  }

  Future<void> _handleConfirmed() async {
    if (_currentPath == null || _isAnalyzing) return;

    final processPath = await _captureSquareImage();

    if (widget.showAnalysis) {
      setState(() => _isAnalyzing = true);
      try {
        final result = await GarmentService().analyzeGarment(processPath);
        debugLog('_handleConfirmed: ${result.metadata}');

        if (!mounted) return;

        Navigator.of(context).pop(
          ImageEditResult(
            imagePath: result.processedImagePath ?? processPath,
            analysisData: result.metadata,
            versatility: result.versatility,
          ),
        );
      } on AuthExpiredException {
        if (!mounted) return;
        await AuthExpiredHandler.handle(context);
      } catch (e) {
        debugLog('Analysis failed: $e');
        if (!mounted) return;
        Navigator.of(context).pop(ImageEditResult(imagePath: processPath));
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
    } else {
      Navigator.of(context).pop(ImageEditResult(imagePath: processPath));
    }
  }

  AppToolBar _buildAppBar(BuildContext context) {
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
        _buildScaffold(context),
        if (_isAnalyzing)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.analyzingClothingEllipsis),
          ),
      ],
    );
  }

  bool get _hasImage => _currentPath != null && _currentPath!.isNotEmpty;

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(context),
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
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return BottomActionButton(
      label: _isAnalyzing ? _l10n.analyzingEllipsis : _l10n.confirmed,
      onPressed: (_hasImage && !_isAnalyzing) ? _handleConfirmed : null,
      trailing: Image.asset(
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
          aspectRatio: 1.0,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowResting,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              // Inside the clip, so capturing this boundary doesn't bake in
              // the rounded corners — just the square photo content.
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
            errorBuilder: (_, __, ___) => const Center(
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
            onTap: _isAnalyzing ? () {} : _handleRetake,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PillButton(
            label: Text(_l10n.album, style: AppTextStyle.bold16),
            icon: Image.asset('assets/images/album.png', height: 32),
            onTap: _isAnalyzing ? () {} : _handleAlbum,
          ),
        ),
      ],
    );
  }
}
