import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/debug_log.dart';
import '../../data/image_edit_result.dart';
import '../../data/location_result.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/fields/labeled_field.dart';
import '../widgets/common/fields/picker_field.dart';
import '../widgets/common/fields/tappable_field_decorator.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/profile_avatar.dart';
import 'image_editor_page.dart';
import 'location_picker_page.dart';
import 'my_virtual_model_page.dart';

/// Height/weight are always stored and saved as cm/kg (see
/// [ProfileService.updateMyProfile]) — this only controls which unit the
/// page displays and accepts input in. Not shared outside this page; promote
/// to a provider if another screen needs to display height/weight in the
/// user's preferred unit too.
enum _UnitSystem {
  metric,
  imperial;

  String get apiValue => this == metric ? 'metric' : 'imperial';

  static _UnitSystem fromApiValue(String? value) =>
      value == 'imperial' ? imperial : metric;
}

class AccountPage extends ConsumerStatefulWidget {
  /// True when opened from HomeGettingStartedView's "About You" step
  /// (`HomePage._openAccountPageForOnboarding`) rather than Settings. Swaps
  /// the bottom action button from "Save" (gated on [_isModified], pops on
  /// success) to "Continue" (gated on the four required fields already
  /// being filled in, pushes [MyVirtualModelPage] on success instead of
  /// popping) — see [_AccountPageState._showsBottomActionButton] and
  /// [_AccountPageState._handleBottomAction].
  final bool completingOnboarding;

  const AccountPage({super.key, this.completingOnboarding = false});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  static const double _cmPerInch = 2.54;
  static const double _kgPerLb = 0.45359237;

  final _nameCtrl = TextEditingController();
  // Canonical values (always cm/kg) — these are what get saved.
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  // Imperial display/input — kept in sync with the canonical controllers
  // above rather than being a second source of truth (see
  // _syncImperialFromMetric and _onImperialHeight/WeightChanged).
  final _heightFeetCtrl = TextEditingController();
  final _heightInchesCtrl = TextEditingController();
  final _weightLbCtrl = TextEditingController();

  bool _loading = false;
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  String? _homeLocation;
  String? _avatarUrl;
  String? _avatarLocalPath;
  bool _avatarUploading = false;
  _UnitSystem _unitSystem = _UnitSystem.metric;

  String _initialName = '';
  String? _initialGender;
  DateTime? _initialBirthDate;
  String? _initialLocation;
  String _initialHeight = '';
  String _initialWeight = '';
  _UnitSystem _initialUnitSystem = _UnitSystem.metric;

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
      _homeLocation != _initialLocation ||
      _heightCtrl.text != _initialHeight ||
      _weightCtrl.text != _initialWeight ||
      _unitSystem != _initialUnitSystem;

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
    // _isModified gets re-evaluated as the user edits a field.
    _nameCtrl.addListener(_onFieldChanged);
    _heightCtrl.addListener(_onFieldChanged);
    _weightCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _heightFeetCtrl.dispose();
    _heightInchesCtrl.dispose();
    _weightLbCtrl.dispose();
    super.dispose();
  }

  void _setUnitSystem(_UnitSystem next) {
    if (next == _unitSystem) return;
    setState(() {
      _unitSystem = next;
      if (next == _UnitSystem.imperial) _syncImperialFromMetric();
    });
  }

  /// Recomputes the ft/in/lb fields from the canonical cm/kg controllers —
  /// called on load and whenever the toggle switches to imperial, since
  /// the imperial fields aren't kept live-updated while hidden.
  void _syncImperialFromMetric() {
    final cm = double.tryParse(_heightCtrl.text);
    if (cm != null) {
      final totalInches = cm / _cmPerInch;
      final feet = (totalInches / 12).floor();
      final inches = (totalInches - feet * 12).round();
      _heightFeetCtrl.text = '$feet';
      _heightInchesCtrl.text = '$inches';
    }
    final kg = double.tryParse(_weightCtrl.text);
    if (kg != null) {
      _weightLbCtrl.text = (kg / _kgPerLb).round().toString();
    }
  }

  // Imperial fields push into the canonical controllers as the user
  // types (one-directional — the metric fields aren't visible at the
  // same time, so there's no risk of the two fighting each other).
  void _onImperialHeightChanged() {
    final feet = double.tryParse(_heightFeetCtrl.text) ?? 0;
    final inches = double.tryParse(_heightInchesCtrl.text) ?? 0;
    if (_heightFeetCtrl.text.isEmpty && _heightInchesCtrl.text.isEmpty) {
      return;
    }
    final cm = (feet * 12 + inches) * _cmPerInch;
    _heightCtrl.text = cm.round().toString();
  }

  void _onImperialWeightChanged() {
    final lb = double.tryParse(_weightLbCtrl.text);
    if (lb == null) return;
    _weightCtrl.text = (lb * _kgPerLb).round().toString();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      // Shared with Settings / My Virtual Model via profileProvider — a
      // no-op fetch if one of those already loaded it.
      final profile = (await ref.read(profileProvider.future)).profile;
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = profile.name;
        _selectedGender = profile.gender;
        _homeLocation = profile.location;
        _avatarUrl = profile.avatarObjectUrl;
        _selectedBirthDate = profile.birthDate;
        final h = profile.height;
        final w = profile.weight;
        if (h != null) _heightCtrl.text = h.toStringAsFixed(0);
        if (w != null) _weightCtrl.text = w.toStringAsFixed(0);
        _unitSystem = _UnitSystem.fromApiValue(profile.unitSystem);
        _syncImperialFromMetric();
        _initialName = _nameCtrl.text.trim();
        _initialGender = _selectedGender;
        _initialBirthDate = _selectedBirthDate;
        _initialLocation = _homeLocation;
        _initialHeight = _heightCtrl.text;
        _initialWeight = _weightCtrl.text;
        _initialUnitSystem = _unitSystem;
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('AccountPage._loadProfile failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.failedToLoad),
      );
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
        // Precache before switching over to it — every upload gets a
        // freshly-signed, genuinely different URL, so plain URL-keyed
        // caching (no separate cache key) already picks up the change; this
        // just confirms the new photo is actually fetchable before the UI
        // commits to it.
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (e) {
          debugLog('_uploadAvatar: failed to precache avatar: $e');
        }
        if (!mounted) return;
        setState(() {
          _avatarUrl = url;
          _avatarLocalPath = null;
        });
        // Re-pull so profileProvider (Settings' avatar, etc.) picks up the
        // new signed URL.
        ref.read(profileProvider.notifier).refresh();
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('AccountPage avatar upload error: $e');
      if (mounted) {
        showErrorDialog(
          context,
          message: apiErrorMessage(_l10n, e, fallback: _l10n.photoUploadFailed),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  /// PATCHes the profile only — no navigation. Returns whether it
  /// succeeded, so callers ([_handleSave]/[_handleContinue]) each decide
  /// what happens next (pop vs. push [MyVirtualModelPage]) rather than this
  /// method assuming one or the other.
  Future<bool> _saveProfile() async {
    setState(() => _loading = true);
    try {
      final result = await ProfileService().updateMyProfile(
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        gender: _selectedGender,
        birthday: _selectedBirthDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
            : null,
        location: _homeLocation,
        height: double.tryParse(_heightCtrl.text.trim()),
        weight: double.tryParse(_weightCtrl.text.trim()),
        unitSystem: _unitSystem.apiValue,
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
      debugLog('AccountPage._saveProfile failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.profileSaveFailed),
      );
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
      MaterialPageRoute(builder: (_) => const MyVirtualModelPage()),
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
        onPressed: widget.completingOnboarding ? _handleContinue : _handleSave,
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
      (widget.completingOnboarding
          ? _hasRequiredAboutYouFields
          : _isModified) &&
      !_loading;

  /// The backend's OpenAPI schema example ("string") occasionally leaks
  /// through as a literal placeholder value instead of a real URL/null —
  /// treat it the same as "no avatar set".
  String? _resolvedAvatarUrl(String? url) =>
      (url == null || url.isEmpty || url == 'string') ? null : url;

  Widget _buildAvatarSection() {
    final url = _avatarLocalPath ?? _resolvedAvatarUrl(_avatarUrl);
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
          const SizedBox(height: 20),
          _buildBodyMeasurementsCard(),
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

  Widget _buildBodyMeasurementsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FieldLabel(_l10n.bodyMeasurementsLabel.toUpperCase()),
            const Spacer(),
            _buildUnitToggle(),
          ],
        ),
        const SizedBox(height: 8),
        AppCardShell(
          child: _unitSystem == _UnitSystem.metric
              ? _buildMetricFields()
              : _buildImperialFields(),
        ),
      ],
    );
  }

  Widget _buildUnitToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.placeholderSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitOption(_UnitSystem.metric, _l10n.unitMetricLabel),
          _buildUnitOption(_UnitSystem.imperial, _l10n.unitImperialLabel),
        ],
      ),
    );
  }

  Widget _buildUnitOption(_UnitSystem value, String label) {
    final selected = _unitSystem == value;
    return GestureDetector(
      // opaque so the padding around the label is tappable — an unselected
      // option's AnimatedContainer is transparent and absorbs nothing.
      behavior: HitTestBehavior.opaque,
      onTap: () => _setUnitSystem(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.shadowResting,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyle.regular12.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  static final _decimalFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
  ];

  Widget _buildMetricFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildMeasurementField(
            controller: _heightCtrl,
            label: _l10n.heightHint,
            unit: 'cm',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMeasurementField(
            controller: _weightCtrl,
            label: _l10n.weightHint,
            unit: 'kg',
          ),
        ),
      ],
    );
  }

  Widget _buildImperialFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildMeasurementField(
            controller: _heightFeetCtrl,
            label: _l10n.feetLabel,
            unit: 'ft',
            onChanged: (_) => _onImperialHeightChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMeasurementField(
            controller: _heightInchesCtrl,
            label: _l10n.inchesLabel,
            unit: 'in',
            onChanged: (_) => _onImperialHeightChanged(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMeasurementField(
            controller: _weightLbCtrl,
            label: _l10n.weightHint,
            unit: 'lb',
            onChanged: (_) => _onImperialWeightChanged(),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementField({
    required TextEditingController controller,
    required String label,
    required String unit,
    ValueChanged<String>? onChanged,
  }) {
    return LabeledField(
      label: label,
      child: AppTextField(
        controller: controller,
        suffixText: unit,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _decimalFormatters,
        onChanged: onChanged,
      ),
    );
  }
}
