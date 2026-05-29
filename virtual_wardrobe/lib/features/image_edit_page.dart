import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/error_handler.dart';
import '../core/services/garments_service.dart';
import 'camera_capture_page.dart';
import '../core/config/app_text_style.dart';
import '../app/theme/app_colors.dart';

class ImageEditResult {
  final String imagePath;
  final Map<String, dynamic>? analysisData;

  ImageEditResult({required this.imagePath, this.analysisData});
}

class ImageEditPage extends StatefulWidget {
  final String? initialPath;
  final bool showAnalysis;

  const ImageEditPage({
    super.key, 
    this.initialPath,
    this.showAnalysis = true,
  });

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
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

  Future<void> _handleConfirmed() async {
    if (_currentPath == null || _isAnalyzing) return;
    
    if (widget.showAnalysis) {
      setState(() => _isAnalyzing = true);
      try {
        final analysisData = await GarmentService().analyzeGarment(_currentPath!);
        
        if (!mounted) return;

        Navigator.of(context).pop(
          ImageEditResult(imagePath: _currentPath!, analysisData: analysisData)
        );
      } on AuthExpiredException {
        if (!mounted) return;
        await AuthExpiredHandler.handle(context);
      } catch (e) {
        debugPrint('Analysis failed: $e');
        if (!mounted) return;
        Navigator.of(context).pop(ImageEditResult(imagePath: _currentPath!));
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
    } else {
      Navigator.of(context).pop(ImageEditResult(imagePath: _currentPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentPath != null && _currentPath!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.toolBar,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => _isAnalyzing ? null : Navigator.pop(context),
        ),
        title: const Text(
          'Edit',
          style: AppTextStyle.bold16,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
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
                                      minScale: 1.0,
                                      maxScale: 4.0,
                                      child: Image.network(_currentPath!, fit: BoxFit.contain),
                                    )
                                  : InteractiveViewer(
                                      transformationController: _transformationController,
                                      minScale: 1.0,
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
                                  height: 20,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_isAnalyzing)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'AI Analyzing...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
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
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: ElevatedButton(
                    onPressed: (hasImage && !_isAnalyzing) ? _handleConfirmed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isAnalyzing ? 'Analyzing...' : 'Confirmed',
                          style: AppTextStyle.bold16.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Image.asset(
                          'assets/images/AI.png',
                          height: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
