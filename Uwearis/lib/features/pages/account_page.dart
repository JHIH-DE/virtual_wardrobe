import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/image_edit_result.dart';
import '../../data/location_result.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/fields/picker_field.dart';
import '../widgets/common/fields/tappable_field_decorator.dart';
import '../widgets/common/overlays/inline_error_text.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/profile_avatar.dart';
import 'image_editor_page.dart';
import 'location_picker_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _nameCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  String? _homeLocation;
  String? _avatarUrl;
  String? _avatarLocalPath;
  bool _avatarUploading = false;

  String _initialName = '';
  String? _initialGender;
  DateTime? _initialBirthDate;
  String? _initialLocation;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  AppLocalizations get _l10n => AppLocalizations.of(context);

  // These map the stable English values stored/sent to the backend to
  // display text — the stored gender value itself must stay in English
  // since that's the wire format `ProfileService.updateMyProfile` expects.
  String _genderDisplayLabel(String value) {
    switch (value) {
      case 'Male':
        return _l10n.genderMale;
      case 'Female':
        return _l10n.genderFemale;
      case 'Other':
        return _l10n.genderOther;
      case 'Prefer not to say':
        return _l10n.genderPreferNotToSay;
      default:
        return value;
    }
  }

  bool get _isModified =>
      _nameCtrl.text.trim() != _initialName ||
      _selectedGender != _initialGender ||
      _selectedBirthDate != _initialBirthDate ||
      _homeLocation != _initialLocation;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Typing doesn't rebuild this widget on its own — force one so
    // _isModified gets re-evaluated as the user edits the name field.
    _nameCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

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
        _nameCtrl.text = profile['name'] ?? '';
        _selectedGender = profile['gender'] as String?;
        _homeLocation = profile['location'] as String?;
        _avatarUrl = profile['avatar_object_url'] as String?;
        final birthdayStr = profile['birthday'] as String?;
        if (birthdayStr != null && birthdayStr.isNotEmpty) {
          try {
            _selectedBirthDate = DateTime.parse(birthdayStr);
          } catch (_) {}
        }
        _initialName = _nameCtrl.text.trim();
        _initialGender = _selectedGender;
        _initialBirthDate = _selectedBirthDate;
        _initialLocation = _homeLocation;
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

  Future<void> _changeAvatar() async {
    final result = await Navigator.push<ImageEditResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          initialPath: _avatarLocalPath ?? _avatarUrl,
          showAnalysis: false,
        ),
      ),
    );
    if (result == null || !mounted) return;
    // Confirmed without picking a new photo — imagePath is still the
    // original signed URL, not a local file. Nothing to upload.
    if (result.imagePath.startsWith('http')) return;
    setState(() => _avatarLocalPath = result.imagePath);
    await _uploadAvatar(result.imagePath);
  }

  Future<void> _uploadAvatar(String localPath) async {
    setState(() => _avatarUploading = true);
    try {
      final init = await ProfileService().avatarInitUpload();
      await ProfileService().putJpegToSignedUrl(init.uploadUrl, localPath);
      final url = await ProfileService().avatarComplete(
        objectName: init.objectName,
      );
      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _avatarLocalPath = null;
        });
      }
    } catch (e) {
      debugLog('AccountPage avatar upload error: $e');
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
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
        location: _homeLocation,
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

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.account);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: BottomActionButton(
        label: _l10n.save,
        onPressed: _saveProfile,
        isLoading: _loading,
        enabled: _isModified,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarSection(),
                  if (_error != null)
                    InlineErrorText(
                      message: _error!,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    ),
                  _buildFormFields(),
                  SizedBox(
                    height: _showsBottomActionButton
                        ? AppDimens.bottomActionBtnClearance
                        : 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showsBottomActionButton => _isModified && !_loading;

  Widget _buildAvatarSection() {
    ImageProvider? avatarProvider;
    if (_avatarLocalPath != null) {
      avatarProvider = FileImage(File(_avatarLocalPath!));
    } else if (_avatarUrl != null &&
        _avatarUrl!.isNotEmpty &&
        _avatarUrl != 'string') {
      avatarProvider = NetworkImage(_avatarUrl!);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        color: AppColors.pageBackground,
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          repeat: ImageRepeat.repeat,
        ),
      ),
      child: Center(
        child: ProfileAvatar(
          image: avatarProvider,
          size: 120,
          onTap: _avatarUploading ? null : _changeAvatar,
        ),
      ),
    );
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

  Widget _buildFormFields() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNameField(),
          const SizedBox(height: 20),
          _buildGenderField(),
          const SizedBox(height: 20),
          _buildBirthdayField(),
          const SizedBox(height: 20),
          _buildLocationField(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(_l10n.accountNameLabel.toUpperCase()),
        const SizedBox(height: 8),
        AppTextField(controller: _nameCtrl, hint: _l10n.enterYourNameHint),
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(_l10n.genderLabel.toUpperCase()),
        const SizedBox(height: 8),
        PickerField(
          text: _selectedGender != null
              ? _genderDisplayLabel(_selectedGender!)
              : '',
          hint: _l10n.selectGenderHint,
          onTap: _loading ? null : _openGenderPicker,
        ),
      ],
    );
  }

  Future<void> _openGenderPicker() async {
    await showPickerSheet<void>(
      context,
      builder: (sheetContext) => RadioGroup<String>(
        groupValue: _selectedGender,
        onChanged: (v) {
          setState(() => _selectedGender = v);
          Navigator.pop(sheetContext);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PickerSheetHeader(_l10n.selectGenderHint),
            for (final g in _genderOptions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _genderDisplayLabel(g),
                  style: g == _selectedGender
                      ? AppTextStyle.bold16
                      : AppTextStyle.regular16,
                ),
                trailing: Radio<String>(
                  value: g,
                  activeColor: AppColors.accent,
                ),
                onTap: () {
                  setState(() => _selectedGender = g);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(_l10n.birthdayLabel.toUpperCase()),
        const SizedBox(height: 8),
        DateDropdownField(
          value: _selectedBirthDate,
          hint: _l10n.selectBirthdayHint,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          onChanged: _loading
              ? null
              : (d) => setState(() => _selectedBirthDate = d),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(_l10n.homeLocationLabel.toUpperCase()),
        const SizedBox(height: 8),
        TappableFieldDecorator(
          onTap: _pickHomeLocation,
          children: [
            Expanded(
              child: Text(
                _homeLocation ?? _l10n.selectYourCityHint,
                style: AppTextStyle.regular16.copyWith(
                  color: _homeLocation == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.icon,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickHomeLocation() async {
    if (_loading) return;
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (result == null) return;
    setState(() => _homeLocation = result.name);
  }
}
