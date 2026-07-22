import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/profile_service.dart';
import '../data/image_edit_result.dart';
import 'image_editor_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/numeric_unit_field.dart';
import 'widgets/common/photo_upload_field.dart';

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
  String _initialHeight = '';
  String _initialWeight = '';

  bool get _isModified =>
      _heightCtrl.text != _initialHeight || _weightCtrl.text != _initialWeight;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Typing doesn't rebuild this widget on its own — force one so
    // _isModified gets re-evaluated as the user edits either field.
    _heightCtrl.addListener(_onFieldChanged);
    _weightCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

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
        _initialHeight = _heightCtrl.text;
        _initialWeight = _weightCtrl.text;
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

  AppToolBar _buildAppBar() {
    return const AppToolBar(title: 'Body Profile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: BottomActionButton(
        label: 'Save',
        onPressed: _saveProfile,
        isLoading: _loading,
        enabled: _isModified,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) _buildErrorBanner(),
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
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        _error!,
        style: AppTextStyle.regular13.copyWith(color: AppColors.error),
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

    return PhotoUploadField(
      imageProvider: provider,
      onTap: _loading ? null : _changeFullBodyPhoto,
      subtitle: 'Please choose a clear, full-body photo.',
    );
  }

  Widget _buildHeightWeightFields() {
    return Row(
      children: [
        Expanded(
          child: NumericUnitField(
            controller: _heightCtrl,
            hint: 'height',
            unit: 'cm',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NumericUnitField(
            controller: _weightCtrl,
            hint: 'weight',
            unit: 'kg',
          ),
        ),
      ],
    );
  }
}
