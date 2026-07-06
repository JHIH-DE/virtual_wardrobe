import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../core/utils/debug_log.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garments_service.dart';
import '../data/image_edit_result.dart';
import 'camera_capture_page.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/page_app_bar.dart';

class ImageEditorPage extends StatefulWidget {
  final String? initialPath;
  final bool showAnalysis;

  const ImageEditorPage({
    super.key, 
    this.initialPath,
    this.showAnalysis = true,
  });

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  String? _currentPath;
  final TransformationController _transformationController = TransformationController();
  bool _isAnalyzing = false;

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

  Future<String> _cropToSquare(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final size = math.min(image.width, image.height);
    final offsetX = (image.width - size) ~/ 2;
    final offsetY = (image.height - size) ~/ 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(offsetX.toDouble(), offsetY.toDouble(), size.toDouble(), size.toDouble()),
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint(),
    );
    final squareImage = await recorder.endRecording().toImage(size, size);
    final byteData = await squareImage.toByteData(format: ui.ImageByteFormat.png);

    final outPath = '${Directory.systemTemp.path}/sq_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outPath).writeAsBytes(byteData!.buffer.asUint8List());
    return outPath;
  }

  Future<void> _handleConfirmed() async {
    if (_currentPath == null || _isAnalyzing) return;

    final isLocal = !_currentPath!.startsWith('http');
    final processPath = isLocal ? await _cropToSquare(_currentPath!) : _currentPath!;

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

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentPath != null && _currentPath!.isNotEmpty;

    return Stack(
      children: [
        Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: 'Edit',
        onBack: () { if (!_isAnalyzing) Navigator.pop(context); },
      ),
      bottomNavigationBar: BottomActionButton(
        label: _isAnalyzing ? 'Analyzing...' : 'Confirmed',
        onPressed: (hasImage && !_isAnalyzing) ? _handleConfirmed : null,
        trailing: Image.asset(
          'assets/images/ai_process.png',
          height: AppDimens.iconSmallSize,
          color: Colors.white,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: hasImage
                              ? (_currentPath!.startsWith('http')
                                  ? InteractiveViewer(
                                      transformationController: _transformationController,
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Image.network(_currentPath!, fit: BoxFit.contain),
                                    )
                                  : InteractiveViewer(
                                      transformationController: _transformationController,
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Image.file(File(_currentPath!), fit: BoxFit.contain),
                                    ))
                              : const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
                        ),
                      ),
                    ),
                    if (hasImage && !_isAnalyzing)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: _resetImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text('Reset', style: AppTextStyle.bold16.copyWith(
                                  color: Colors.white,
                                )),
                                const SizedBox(width: 8),
                                Image.asset(
                                  'assets/images/reset.png',
                                  height: AppDimens.iconSmallSize,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/pinch.png',
                        height: 54,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pinch to zoom the image to make sure the picture have the whole details.',
                        style: AppTextStyle.bold16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        label: const Text(
                          'Retake',
                          style: AppTextStyle.bold16,
                        ),
                        icon: Image.asset(
                          'assets/images/camera.png',
                          height: 32,
                        ),
                        onTap: _isAnalyzing ? () {} : _handleRetake,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionBtn(
                        label: const Text(
                          'Album',
                          style: AppTextStyle.bold16,
                        ),
                        icon: Image.asset(
                          'assets/images/album.png',
                          height: 32,
                        ),
                        onTap: _isAnalyzing ? () {} : _handleAlbum,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ),
        ),
        if (_isAnalyzing)
          const Positioned.fill(child: LoadingOverlay(label: 'Analyzing Clothing...')),
      ],
    );
  }

  Widget _buildActionBtn({
    required Widget label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            label,
            icon,
          ],
        ),
      ),
    );
  }
}
