import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'garment_category.dart';
import 'theme/app_colors.dart';

class AddGarmentPage extends StatefulWidget {
  const AddGarmentPage({super.key});

  @override
  State<AddGarmentPage> createState() => _AddGarmentPageState();
}

class _AddGarmentPageState extends State<AddGarmentPage> {
  GarmentCategory category = GarmentCategory.top;

  final ImagePicker _picker = ImagePicker();
  File? originalFile;
  File? croppedFile;
  File? compressedFile;

  bool uploading = false;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final displayFile = compressedFile ?? croppedFile ?? originalFile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Item'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) Category
          _sectionTitle('Select category'),
          const SizedBox(height: 8),
          DropdownButtonFormField<GarmentCategory>(
            value: category,
            items: GarmentCategory.values
                .map((c) => DropdownMenuItem(
              value: c,
              child: Text(c.label),
            ))
                .toList(),
            onChanged: uploading ? null : (v) => setState(() => category = v!),
          ),

          const SizedBox(height: 18),

          // 2) Image
          _sectionTitle('Choose image'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: _outlineBtnStyle(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                  style: _outlineBtnStyle(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Preview frame
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
                    ? Center(
                  child: Text(
                    'No image selected',
                    style: const TextStyle(color: AppColors.textSecondary),
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
                  onPressed: (originalFile == null || uploading) ? null : _cropImage,
                  style: _outlineBtnStyle(),
                  child: const Text('Crop'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: ((croppedFile == null && originalFile == null) || uploading)
                      ? null
                      : _compressImage,
                  style: _outlineBtnStyle(),
                  child: const Text('Compress'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3) Upload
          _sectionTitle('Upload'),
          const SizedBox(height: 10),

          if (uploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(minHeight: 4),
            ),
            const SizedBox(height: 12),
          ],

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
            const SizedBox(height: 12),
          ],

          ElevatedButton.icon(
            onPressed: uploading ? null : _submit,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 10),
          const Text(
            'Your item will be saved to the selected category.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
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

  InputDecoration _inputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
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
      imageQuality: null, // 不用這個，因為我們要自己控制壓縮
    );

    if (xfile == null) return;

    setState(() {
      originalFile = File(xfile.path);
    });

    // 一選到就先做壓縮（可讓使用者更快看到縮圖）
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

    // 壓縮：長邊 1024~1536 之間，先用 1536 兼顧畫質
    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      outPath,
      quality: 80,       // 70~85 之間，先用 80
      minWidth: 1536,    // 會依比例縮放（不一定兩邊都到）
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

  Future<void> _submit() async {
    final file = compressedFile ?? croppedFile ?? originalFile;
    if (file == null) {
      setState(() => errorMessage = 'Please select an image first.');
      return;
    }

    setState(() {
      uploading = true;
      errorMessage = null;
    });

    try {
      // TODO: 這裡改成你後端流程：
      // 1) POST /garments/upload-url -> signed_url
      // 2) PUT file to signed_url
      // 3) POST /garments {image_url, category}
      await Future.delayed(const Duration(milliseconds: 800));

      // 先把結果帶回 Items Tab（讓你可以更新 UI）
      if (!mounted) return;
      Navigator.pop(context, {
        'category': category.apiValue,
        'local_path': file.path, // demo 用，本來應該回 image_url
      });
    } catch (e) {
      setState(() => errorMessage = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }
}