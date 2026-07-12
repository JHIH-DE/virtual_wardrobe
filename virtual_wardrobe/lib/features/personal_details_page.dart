import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/base_service.dart';
import '../core/services/profile_service.dart';
import 'image_editor_page.dart';
import 'widgets/common/app_text_field.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/custom_dropdown.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/common/profile_avatar.dart';
import 'widgets/common/required_field_label.dart';

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
            ImageEditorPage(initialPath: _avatarLocalPath ?? _avatarUrl),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          _error!,
                          style: AppTextStyle.regular13.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    _buildAvatarSection(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RequiredFieldLabel('Account Name'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _nameCtrl,
                            hint: 'Enter your name',
                          ),
                          const SizedBox(height: 20),
                          RequiredFieldLabel('Gender'),
                          const SizedBox(height: 8),
                          CustomDropdown<String>(
                            value: _selectedGender,
                            hint: 'Select gender',
                            items: _genderOptions
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ),
                                )
                                .toList(),
                            onChanged: _loading
                                ? null
                                : (v) => setState(() => _selectedGender = v),
                          ),
                          const SizedBox(height: 20),
                          RequiredFieldLabel('Birthday'),
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

  Widget _buildAvatarSection() {
    final avatarImage = _avatarLocalPath != null
        ? FileImage(File(_avatarLocalPath!)) as ImageProvider
        : (_avatarUrl != null &&
                  _avatarUrl!.isNotEmpty &&
                  _avatarUrl != 'string'
              ? NetworkImage(_avatarUrl!) as ImageProvider
              : null);

    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/personal_details_background.png',
              fit: BoxFit.cover,
            ),
            Center(
              child: ProfileAvatar(
                image: avatarImage,
                onTap: _loading ? null : _changeAvatar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

}
