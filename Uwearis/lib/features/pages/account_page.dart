import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/image_cache_bust.dart';
import '../../data/image_edit_result.dart';
import '../../data/location_result.dart';
import '../../data/user_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/fields/labeled_field.dart';
import '../widgets/common/fields/picker_field.dart';
import '../widgets/common/fields/tappable_field_decorator.dart';
import '../widgets/common/overlays/inline_error_text.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/profile_avatar.dart';
import 'image_editor_page.dart';
import 'location_picker_page.dart';
import 'tryon_profile_page.dart';

class AccountPage extends ConsumerStatefulWidget {
  /// True when opened from HomeGettingStartedView's "About You" step
  /// (`HomePage._openAccountPageForOnboarding`) rather than Settings. Swaps
  /// the bottom action button from "Save" (gated on [_isModified], pops on
  /// success) to "Continue" (gated on the four required fields already
  /// being filled in, pushes [TryonProfilePage] on success instead of
  /// popping) — see [_AccountPageState._showsBottomActionButton] and
  /// [_AccountPageState._handleBottomAction].
  final bool completingOnboarding;

  const AccountPage({super.key, this.completingOnboarding = false});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
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

  /// The onboarding "About You" step's completion rule — all four fields
  /// non-empty. Deliberately unrelated to [_isModified]: a user who already
  /// filled these in during an earlier visit (nothing changed *this*
  /// session) should still see Continue immediately, not just after they
  /// edit something.
  bool get _hasRequiredAboutYouFields =>
      _nameCtrl.text.trim().isNotEmpty &&
      _selectedGender != null &&
      _selectedBirthDate != null &&
      (_homeLocation?.isNotEmpty ?? false);

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
      // Shared with Settings / Try-on Profile via profileProvider — a
      // no-op fetch if one of those already loaded it.
      final profile = (await ref.read(profileProvider.future)).profile;
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = profile.name;
        _selectedGender = profile.gender;
        _homeLocation = profile.location;
        _avatarUrl = profile.avatarObjectUrl;
        _selectedBirthDate = profile.birthDate;
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
          title: _l10n.profilePhotoTitle,
          initialPath: _avatarLocalPath ?? _avatarUrl,
          showAnalysis: false,
          // This reopens the already-saved avatar — confirming with zero
          // changes would just re-upload an identical copy.
          requireChangeToConfirm: true,
          onRefreshUrl: () => ProfileService().getMyAvatar(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _avatarLocalPath = result.imagePath);
    await _uploadAvatar(result.imagePath);
  }

  Future<void> _uploadAvatar(String localPath) async {
    setState(() => _avatarUploading = true);
    try {
      final url = await ProfileService().uploadAvatar(localPath);
      if (mounted) {
        ImageCacheBust.bump(avatarImageCacheKey);
        setState(() {
          _avatarUrl = url;
          _avatarLocalPath = null;
        });
        // Re-pull so profileProvider (Settings' avatar, etc.) picks up the
        // new signed URL.
        ref.read(profileProvider.notifier).refresh();
      }
    } catch (e) {
      debugLog('AccountPage avatar upload error: $e');
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  /// PATCHes the profile only — no navigation. Returns whether it
  /// succeeded, so callers ([_handleSave]/[_handleContinue]) each decide
  /// what happens next (pop vs. push [TryonProfilePage]) rather than this
  /// method assuming one or the other.
  Future<bool> _saveProfile() async {
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
      if (!mounted) return false;
      ref.read(profileProvider.notifier).setProfile(result);
      return true;
    } on AuthExpiredException {
      if (!mounted) return false;
      await AuthExpiredHandler.handle(context);
      return false;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _error = e.toString());
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSave() async {
    if (await _saveProfile() && mounted) Navigator.pop(context);
  }

  /// Only re-saves if something was actually edited this session — a user
  /// who arrives with the four fields already filled from an earlier visit
  /// can just continue straight on without an unnecessary PATCH.
  Future<void> _handleContinue() async {
    if (_isModified && !await _saveProfile()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TryonProfilePage()),
    );
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
        label: widget.completingOnboarding ? _l10n.continueLabel : _l10n.save,
        onPressed: widget.completingOnboarding
            ? _handleContinue
            : _handleSave,
        isLoading: _loading,
        enabled: widget.completingOnboarding
            ? _hasRequiredAboutYouFields
            : _isModified,
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

  bool get _showsBottomActionButton =>
      (widget.completingOnboarding ? _hasRequiredAboutYouFields : _isModified) &&
      !_loading;

  /// The backend's OpenAPI schema example ("string") occasionally leaks
  /// through as a literal placeholder value instead of a real URL/null —
  /// treat it the same as "no avatar set".
  String? _resolvedAvatarUrl(String? url) =>
      (url == null || url.isEmpty || url == 'string') ? null : url;

  Widget _buildAvatarSection() {
    final url = _avatarLocalPath ?? _resolvedAvatarUrl(_avatarUrl);
    final baseKey = avatarImageCacheKey;
    final cacheKey = '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
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
          url: url,
          cacheKey: cacheKey,
          onRefreshUrl: () => ProfileService().getMyAvatar(),
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
    return LabeledField(
      label: _l10n.accountNameLabel,
      child: AppTextField(controller: _nameCtrl, hint: _l10n.enterYourNameHint),
    );
  }

  Widget _buildGenderField() {
    return LabeledField(
      label: _l10n.genderLabel,
      child: PickerField(
        text: _selectedGender != null
            ? _genderDisplayLabel(_selectedGender!)
            : '',
        hint: _l10n.selectGenderHint,
        onTap: _loading ? null : _openGenderPicker,
      ),
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
    return LabeledField(
      label: _l10n.birthdayLabel,
      child: DateDropdownField(
        value: _selectedBirthDate,
        hint: _l10n.selectBirthdayHint,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        onChanged: _loading
            ? null
            : (d) => setState(() => _selectedBirthDate = d),
      ),
    );
  }

  Widget _buildLocationField() {
    return LabeledField(
      label: _l10n.homeLocationLabel,
      child: TappableFieldDecorator(
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
