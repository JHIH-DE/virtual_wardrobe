import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/debug_log.dart';
import '../../l10n/generated/app_localizations.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
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
    final boxSize = size.width * 0.85;

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildMaskWithHole(boxSize),
          _buildHighlightBorder(boxSize),
          _buildHeader(),
          _buildCaptureButton(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Positioned.fill(child: CameraPreview(_controller!));
  }

  // Mask with a cutout square
  Widget _buildMaskWithHole(double boxSize) {
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
              width: boxSize,
              height: boxSize,
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

  // White border and center crosshair
  Widget _buildHighlightBorder(double boxSize) {
    return Center(
      child: SizedBox(
        width: boxSize,
        height: boxSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textOnPrimary, width: 3),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            // Center crosshair
            Container(width: 30, height: 2, color: AppColors.textOnPrimary),
            Container(width: 2, height: 30, color: AppColors.textOnPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 120,
        padding: const EdgeInsets.only(top: 40),
        color: AppColors.scrimMedium,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                AppLocalizations.of(context).camera,
                textAlign: TextAlign.center,
                style: AppTextStyle.bold16.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
            const SizedBox(width: 48), // Spacer for center alignment
          ],
        ),
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
