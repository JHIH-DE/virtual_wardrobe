import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/profile_service.dart';
import '../data/image_edit_result.dart';
import 'image_editor_page.dart';
import 'widgets/app_text_field.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/page_app_bar.dart';

class BodyProfilePage extends StatefulWidget {
  const BodyProfilePage({super.key});

  @override
  State<BodyProfilePage> createState() => _BodyProfilePageState();
}

class _BodyProfilePageState extends State<BodyProfilePage> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _fullBodyUrl;
  String? _fullBodyLocalPath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ProfileService().getMyProfile(),
        ProfileService().getMyFullBody(),
      ]);
      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final fullBodyUrl = results[1] as String?;
      setState(() {
        final h = profile['height'];
        final w = profile['weight'];
        if (h != null) _heightCtrl.text = (h as num).toStringAsFixed(0);
        if (w != null) _weightCtrl.text = (w as num).toStringAsFixed(0);
        _fullBodyUrl = fullBodyUrl;
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final h = double.tryParse(_heightCtrl.text.trim());
      final w = double.tryParse(_weightCtrl.text.trim());
      await ProfileService().updateMyProfile(height: h, weight: w);
      if (!mounted) return;
      Navigator.pop(context);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeFullBodyPhoto() async {
    final result = await Navigator.push<ImageEditResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          initialPath: _fullBodyLocalPath ?? _fullBodyUrl,
          showAnalysis: false,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _fullBodyLocalPath = result.imagePath);
    await _uploadFullBody(result.imagePath);
  }

  Future<void> _uploadFullBody(String localPath) async {
    setState(() => _loading = true);
    try {
      final init = await ProfileService().fullBodyInitUpload();
      await ProfileService().putJpegToSignedUrl(init.uploadUrl, localPath);
      final url = await ProfileService().fullBodyComplete(
        objectName: init.objectName,
      );
      if (mounted) {
        setState(() {
          _fullBodyUrl = url;
          _fullBodyLocalPath = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: const PageAppBar(title: 'Body Profile'),
      bottomNavigationBar: BottomActionButton(
        label: 'Save',
        onPressed: _loading ? null : _saveProfile,
        isLoading: _loading,
        buttonColor: AppColors.nearBlack,
        textColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: AppTextStyle.regular13.copyWith(color: Colors.red),
                  ),
                ),
              const Text('Full-body Photo', style: AppTextStyle.bold14),
              const SizedBox(height: 10),
              _buildPhotoUpload(),
              const SizedBox(height: 24),
              const Text('Figure Detail', style: AppTextStyle.bold14),
              const SizedBox(height: 10),
              _buildHeightWeightFields(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUpload() {
    ImageProvider? provider;
    if (_fullBodyLocalPath != null) {
      provider = FileImage(File(_fullBodyLocalPath!));
    } else if (_fullBodyUrl != null &&
        _fullBodyUrl!.isNotEmpty &&
        _fullBodyUrl != 'string') {
      provider = NetworkImage(_fullBodyUrl!);
    }

    if (provider != null) {
      return Center(
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: GestureDetector(
            onTap: _loading ? null : _changeFullBodyPhoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image(image: provider, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _loading ? null : _changeFullBodyPhoto,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.placeholderBorder,
          radius: 16,
        ),
        child: Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            color: AppColors.placeholderBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Upload Image', style: AppTextStyle.semibold16),
              const SizedBox(height: 6),
              Text(
                'Please choose a clear, full-body photo.',
                style: AppTextStyle.regular13.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loading ? null : _changeFullBodyPhoto,
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Choose photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.textPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeightWeightFields() {
    return Row(
      children: [
        Expanded(
          child: _unitField(_heightCtrl, hint: 'height', unit: 'cm'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _unitField(_weightCtrl, hint: 'weight', unit: 'kg'),
        ),
      ],
    );
  }

  Widget _unitField(
    TextEditingController ctrl, {
    required String hint,
    required String unit,
  }) {
    return AppTextField(
      controller: ctrl,
      hint: hint,
      suffixText: unit,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const sw = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sw / 2, sw / 2, size.width - sw, size.height - sw),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segmentEnd = (distance + (draw ? 8.0 : 5.0)).clamp(
          0.0,
          metric.length,
        );
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, segmentEnd), paint);
        }
        distance = segmentEnd;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
