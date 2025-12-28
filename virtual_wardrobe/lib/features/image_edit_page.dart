import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app/theme/app_colors.dart';

class ImageEditPage extends StatefulWidget {
  /// initialPath supports local file path (demo mode)
  final String? initialPath;

  const ImageEditPage({super.key, this.initialPath});

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  final ImagePicker _picker = ImagePicker();

  File? originalFile;
  File? croppedFile;
  File? compressedFile;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty && !path.startsWith('http')) {
      originalFile = File(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayFile = compressedFile ?? croppedFile ?? originalFile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Image'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          TextButton(
            onPressed: displayFile == null ? null : () => Navigator.pop(context, displayFile!.path),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Choose image'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: _outlineBtnStyle(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                  style: _outlineBtnStyle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: displayFile == null
                    ? const Center(
                  child: Text(
                    'No image selected',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
                    : Image.file(displayFile, fit: BoxFit.cover),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (originalFile == null) ? null : _cropImage,
                  style: _outlineBtnStyle(),
                  child: const Text('Crop'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: ((croppedFile == null && originalFile == null)) ? null : _compressImage,
                  style: _outlineBtnStyle(),
                  child: const Text('Compress'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }

  ButtonStyle _outlineBtnStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      errorMessage = null;
      originalFile = null;
      croppedFile = null;
      compressedFile = null;
    });

    final XFile? xfile = await _picker.pickImage(
      source: source,
      imageQuality: null,
    );

    if (xfile == null) return;

    setState(() {
      originalFile = File(xfile.path);
    });

    await _compressImage();
  }

  Future<void> _cropImage() async {
    final file = originalFile;
    if (file == null) return;

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.white,
          ),
          IOSUiSettings(title: 'Crop'),
        ],
      );

      if (cropped == null) return;

      setState(() {
        croppedFile = File(cropped.path);
        compressedFile = null;
      });

      await _compressImage();
    } catch (e) {
      setState(() {
        errorMessage = 'Crop failed. Please try again.';
      });
    }
  }

  Future<void> _compressImage() async {
    final input = croppedFile ?? originalFile;
    if (input == null) return;

    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'garment_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      outPath,
      quality: 80,
      minWidth: 1536,
      minHeight: 1536,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      setState(() => errorMessage = 'Failed to compress image.');
      return;
    }

    setState(() {
      compressedFile = File(result.path);
    });
  }
}