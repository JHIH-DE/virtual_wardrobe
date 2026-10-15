import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/debug_log.dart';
import '../../l10n/generated/app_localizations.dart';

/// The cutout shape. Only a framing guide — the capture is always
/// full-frame and gets cropped later in the image editor.
enum CameraFrameRatio {
  square(1, 1, '1:1'),
  portrait(2, 3, '2:3');

  const CameraFrameRatio(this.w, this.h, this.label);

  final double w;
  final double h;
  final String label;

  double heightFor(double width) => width * h / w;
}

class CameraCapturePage extends StatefulWidget {
  final CameraFrameRatio initialRatio;

  const CameraCapturePage({
    super.key,
    this.initialRatio = CameraFrameRatio.square,
  });

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _isInitialized = false;
  // A second tap mid-swap would race two CameraControllers onto one texture.
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _startController(_cameras[_cameraIndex]);
  }

  Future<void> _startController(CameraDescription description) async {
    // Dispose first: iOS AVFoundation won't run two sessions at once, and
    // the new preview stays black.
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      debugLog('Camera initialize failed: $e');
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _isInitialized = true;
    });
  }

  Future<void> _switchCamera() async {
    if (_switching || _cameras.length < 2) return;
    _switching = true;
    setState(() => _isInitialized = false);
    try {
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      debugLog('Error switching camera: $e');
    } finally {
      _switching = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile photo = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, photo.path);
    } catch (e) {
      debugLog('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: AppColors.trueBlack,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.textOnPrimary),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    // Clamp the height and back-solve the width so the ratio always holds.
    final ratio = widget.initialRatio;
    final maxBoxW = size.width * 0.85;
    final maxBoxH = size.height * 0.60;
    var boxW = maxBoxW;
    var boxH = ratio.heightFor(boxW);
    if (boxH > maxBoxH) {
      boxH = maxBoxH;
      boxW = boxH * ratio.w / ratio.h;
    }
    final box = Size(boxW, boxH);

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildMaskWithHole(box),
          _buildHighlightBorder(box),
          _buildHeader(),
          _buildCaptureButton(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Positioned.fill(child: CameraPreview(_controller!));
  }

  Widget _buildMaskWithHole(Size box) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(AppColors.scrimStrong, BlendMode.srcOut),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.trueBlack,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: box.width,
              height: box.height,
              decoration: BoxDecoration(
                color: AppColors.textOnPrimary,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightBorder(Size box) {
    return Center(
      child: SizedBox(
        width: box.width,
        height: box.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: _ViewfinderCornersPainter(
                  color: AppColors.textOnPrimary,
                  cornerRadius: 32,
                  armLength: 56,
                  strokeWidth: 6,
                ),
              ),
            ),
            _crosshairBar(width: 48, height: 5),
            _crosshairBar(width: 5, height: 48),
          ],
        ),
      ),
    );
  }

  Widget _crosshairBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: AppColors.scrimMedium,
        // Deliberately not an AppToolBar (immersive, white-tinted), but
        // sized to match one.
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppDimens.toolbarHeight,
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppDimens.toolbarHeight,
                    minHeight: AppDimens.toolbarHeight,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: AppDimens.backArrowIconSize,
                    color: AppColors.textOnPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).camera,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: AppTextStyle.bold20.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
                _cameras.length >= 2
                    ? _buildSwitchCameraAction()
                    : const SizedBox(width: AppDimens.toolbarHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchCameraAction() {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).switchCamera,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: AppDimens.toolbarHeight,
          minHeight: AppDimens.toolbarHeight,
        ),
        icon: const Icon(
          Icons.cameraswitch_outlined,
          size: AppDimens.toolbarActionIconSize,
          color: AppColors.textOnPrimary,
        ),
        onPressed: _switching ? null : _switchCamera,
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _takePicture,
          child: Container(
            height: 84,
            width: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textOnPrimary, width: 5),
            ),
            child: Center(
              child: Container(
                height: 64,
                width: 64,
                decoration: const BoxDecoration(
                  color: AppColors.textOnPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The four rounded corner brackets of a viewfinder frame; the arc radius
/// matches the cutout's.
class _ViewfinderCornersPainter extends CustomPainter {
  const _ViewfinderCornersPainter({
    required this.color,
    required this.cornerRadius,
    required this.armLength,
    required this.strokeWidth,
  });

  final Color color;
  final double cornerRadius;

  /// Straight-stub length past the end of each corner arc.
  final double armLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Offset by half the stroke so the thick line sits just outside the
    // cutout, concentric with its rounded corner.
    final o = strokeWidth / 2;
    final l = -o;
    final t = -o;
    final r = size.width + o;
    final b = size.height + o;
    final rad = cornerRadius + o;
    final arm = armLength;
    final corner = Radius.circular(rad);

    final path = Path()
      // top-left
      ..moveTo(l, t + rad + arm)
      ..lineTo(l, t + rad)
      ..arcToPoint(Offset(l + rad, t), radius: corner)
      ..lineTo(l + rad + arm, t)
      // top-right
      ..moveTo(r - rad - arm, t)
      ..lineTo(r - rad, t)
      ..arcToPoint(Offset(r, t + rad), radius: corner)
      ..lineTo(r, t + rad + arm)
      // bottom-right
      ..moveTo(r, b - rad - arm)
      ..lineTo(r, b - rad)
      ..arcToPoint(Offset(r - rad, b), radius: corner)
      ..lineTo(r - rad - arm, b)
      // bottom-left
      ..moveTo(l + rad + arm, b)
      ..lineTo(l + rad, b)
      ..arcToPoint(Offset(l, b - rad), radius: corner)
      ..lineTo(l, b - rad - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ViewfinderCornersPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.armLength != armLength ||
      oldDelegate.strokeWidth != strokeWidth;
}
