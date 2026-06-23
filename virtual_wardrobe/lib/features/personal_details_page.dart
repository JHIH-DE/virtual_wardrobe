import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/base_service.dart';
import '../core/services/profile_service.dart';
import 'image_edit_page.dart';
import 'widgets/custom_dropdown.dart';
import 'widgets/page_app_bar.dart';
import 'widgets/app_text_field.dart';
import 'widgets/bottom_action_button.dart';

class PersonalDetailsPage extends StatefulWidget {
  const PersonalDetailsPage({super.key});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final _nameCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _avatarUrl;
  String? _avatarLocalPath;
  String? _selectedGender;
  DateTime? _selectedBirthDate;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService().getMyProfile();
      if (!mounted) return;
      setState(() {
        _avatarUrl = profile['avatar_object_url'] as String?;
        _nameCtrl.text = profile['name'] ?? '';
        _selectedGender = profile['gender'] as String?;
        final birthdayStr = profile['birthday'] as String?;
        if (birthdayStr != null && birthdayStr.isNotEmpty) {
          try {
            _selectedBirthDate = DateTime.parse(birthdayStr);
          } catch (_) {}
        }
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
      final result = await ProfileService().updateMyProfile(
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        gender: _selectedGender,
        birthday: _selectedBirthDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
            : null,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
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

  Future<void> _changeAvatar() async {
    final picked = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImageEditPage(initialPath: _avatarLocalPath ?? _avatarUrl),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _avatarLocalPath = picked);
    await _uploadAvatar(picked);
  }

  Future<void> _uploadProfileImage(
    String localPath, {
    required Future<InitUploadResult> Function() initUpload,
    required Future<String> Function({required String objectName}) complete,
    required void Function(bool) setLoading,
    required void Function(String url) onSuccess,
  }) async {
    setLoading(true);
    try {
      final init = await initUpload();
      await ProfileService().putJpegToSignedUrl(init.uploadUrl, localPath);
      final newUrl = await complete(objectName: init.objectName);
      if (mounted) onSuccess(newUrl);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setLoading(false);
    }
  }

  Future<void> _uploadAvatar(String localPath) => _uploadProfileImage(
        localPath,
        initUpload: ProfileService().avatarInitUpload,
        complete: ProfileService().avatarComplete,
        setLoading: (v) => setState(() => _loading = v),
        onSuccess: (url) => setState(() {
          _avatarUrl = url;
          _avatarLocalPath = null;
        }),
      );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(title: 'Personal Details'),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: AppTextStyle.regular13.copyWith(color: Colors.red)),
                    ),
                  _buildAvatarBanner(),
                  const SizedBox(height: 24),
                  _fieldLabel('Account Name'),
                  const SizedBox(height: 8),
                  AppTextField(controller: _nameCtrl, hint: 'Enter your name'),
                  const SizedBox(height: 20),
                  _fieldLabel('Gender'),
                  const SizedBox(height: 8),
                  CustomDropdown<String>(
                    value: _selectedGender,
                    hint: 'Select gender',
                    items: _genderOptions
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _selectedGender = v),
                  ),
                  const SizedBox(height: 20),
                  _fieldLabel('Birthday'),
                  const SizedBox(height: 8),
                  DateDropdownField(
                    value: _selectedBirthDate,
                    hint: 'Select birthday',
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    onChanged: _loading
                        ? null
                        : (d) => setState(() => _selectedBirthDate = d),
                  ),
                ],
              ),
            ),
          ),
          BottomActionButton(
            label: 'Save',
            onPressed: _saveProfile,
            isLoading: _loading,
          ),
        ],
      ),
      ),
    );
  }

  // ── Avatar banner ──────────────────────────────────────────────────────────

  Widget _buildAvatarBanner() {
    ImageProvider? provider;
    if (_avatarLocalPath != null) {
      provider = FileImage(File(_avatarLocalPath!));
    } else if (_avatarUrl != null &&
        _avatarUrl!.isNotEmpty &&
        _avatarUrl != 'string') {
      provider = NetworkImage(_avatarUrl!);
    }

    return GestureDetector(
      onTap: _loading ? null : _changeAvatar,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFECF1FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6B9BF5), width: 1.5),
        ),
        child: Stack(
          children: [
            ..._scatteredIcons(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white,
                    backgroundImage: provider,
                    child: provider == null
                        ? const Icon(Icons.person,
                            size: 40, color: AppColors.textSecondary)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Edit Photo',
                      style: AppTextStyle.regular12.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _scatteredIcons() {
    const color = Color(0xFF6B9BF5);
    const ops = 0.3;
    return [
      _icon(Icons.checkroom_outlined, 22, 18, color, ops),
      _icon(Icons.style_outlined, 260, 14, color, ops),
      _icon(Icons.dry_cleaning_outlined, 12, 96, color, ops),
      _icon(Icons.auto_awesome_outlined, 278, 88, color, ops),
      _icon(Icons.face_outlined, 48, 144, color, ops),
      _icon(Icons.storefront_outlined, 244, 140, color, ops),
      _icon(Icons.star_outline, 146, 8, color, ops),
      _icon(Icons.design_services_outlined, 136, 152, color, ops),
    ];
  }

  Widget _icon(IconData icon, double left, double top, Color color, double opacity) {
    return Positioned(
      left: left,
      top: top,
      child: Icon(icon, size: 22, color: color.withOpacity(opacity)),
    );
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

  Widget _fieldLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyle.semibold14,
        ),
        const SizedBox(width: 4),
        Text('✳', style: AppTextStyle.regular12.copyWith(color: Colors.red)),
      ],
    );
  }

}
