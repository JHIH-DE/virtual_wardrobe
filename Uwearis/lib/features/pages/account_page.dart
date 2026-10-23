import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/auto_save_controller.dart';
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
import '../widgets/common/overlays/auto_save_prompts.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/profile_avatar.dart';
import 'image_editor_page.dart';
import 'location_picker_page.dart';
import 'my_outfit_profile_page.dart';

/// Display/input unit only — height/weight are always saved as cm/kg.
enum _UnitSystem {
  metric,
  imperial;

  String get apiValue => this == metric ? 'metric' : 'imperial';

  static _UnitSystem fromApiValue(String? value) =>
      value == 'imperial' ? imperial : metric;
}

class AccountPage extends ConsumerStatefulWidget {
  /// Onboarding's "About You" step: an explicit Continue button instead of
  /// auto-save, which then pushes [MyOutfitProfilePage].
  final bool completingOnboarding;

  const AccountPage({super.key, this.completingOnboarding = false});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  static const double _cmPerInch = 2.54;
  static const double _kgPerLb = 0.45359237;
  static const double _avatarSize = 120;

  final _nameCtrl = TextEditingController();
  // Canonical cm/kg — what gets saved.
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  // Imperial display/input, synced into the canonical controllers.
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

  // Settings mode only — onboarding saves on Continue.
  late final AutoSaveController _autoSave = AutoSaveController(
    onSave: _persistProfile,
    onError: (e) => showAutoSaveErrorDialog(
      context,
      _autoSave,
      e,
      fallback: _l10n.profileSaveFailed,
    ),
  );
  bool _leaving = false;
  bool _savingBeforeLeave = false;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  AppLocalizations get _l10n => AppLocalizations.of(context);

  // The stored gender value stays English — it's the backend wire format.
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

  /// Onboarding only — auto-save doesn't use it.
  bool get _isModified =>
      _nameCtrl.text.trim() != _initialName ||
      _selectedGender != _initialGender ||
      _selectedBirthDate != _initialBirthDate ||
      _homeLocation != _initialLocation ||
      _heightCtrl.text != _initialHeight ||
      _weightCtrl.text != _initialWeight ||
      _unitSystem != _initialUnitSystem;

  /// Deliberately not tied to [_isModified]: fields filled on an earlier
  /// visit should show Continue immediately.
  bool get _hasRequiredAboutYouFields =>
      _nameCtrl.text.trim().isNotEmpty &&
      _selectedGender != null &&
      _selectedBirthDate != null &&
      (_homeLocation?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Rebuild on typing so onboarding's Continue gate re-evaluates.
    _nameCtrl.addListener(_onFieldChanged);
    _heightCtrl.addListener(_onFieldChanged);
    _weightCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _autoSave.dispose();
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _heightFeetCtrl.dispose();
    _heightInchesCtrl.dispose();
    _weightLbCtrl.dispose();
    super.dispose();
  }

  /// Onboarding saves only on Continue; otherwise typing is debounced and
  /// everything else saves immediately.
  void _onEdited({bool typing = false}) {
    if (widget.completingOnboarding) return;
    if (typing) {
      _autoSave.scheduleSave();
    } else {
      _autoSave.requestSave();
    }
  }

  /// Blur / Done skips the debounce. Not after a failure, so it doesn't
  /// re-raise the error dialog the user just dismissed.
  void _onTextFieldBlur() {
    if (_autoSave.hasPendingChanges && !_autoSave.hasFailed) {
      _autoSave.requestSave();
    }
  }

  void _setUnitSystem(_UnitSystem next) {
    if (next == _unitSystem) return;
    setState(() {
      _unitSystem = next;
      if (next == _UnitSystem.imperial) _syncImperialFromMetric();
    });
    _onEdited();
  }

  /// The imperial fields aren't updated while hidden, so recompute them on
  /// load and when switching to imperial.
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

  // One-directional: metric fields aren't visible at the same time.
  void _onImperialHeightChanged() {
    final feet = double.tryParse(_heightFeetCtrl.text) ?? 0;
    final inches = double.tryParse(_heightInchesCtrl.text) ?? 0;
    if (_heightFeetCtrl.text.isEmpty && _heightInchesCtrl.text.isEmpty) {
      return;
    }
    final cm = (feet * 12 + inches) * _cmPerInch;
    _heightCtrl.text = cm.round().toString();
    _onEdited(typing: true);
  }

  void _onImperialWeightChanged() {
    final lb = double.tryParse(_weightLbCtrl.text);
    if (lb == null) return;
    _weightCtrl.text = (lb * _kgPerLb).round().toString();
    _onEdited(typing: true);
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
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
          // Confirming with zero changes would re-upload an identical copy.
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
        // Each upload gets a new signed URL, so no cache key is needed.
        // Precache is best-effort: a failure is logged and the URL is used anyway.
        try {
          await precacheImage(
            ResizeImage(
              CachedNetworkImageProvider(url),
              width: ProfileAvatar.decodeWidth(context, _avatarSize),
            ),
            context,
          );
        } catch (e) {
          debugLog('_uploadAvatar: failed to precache avatar: $e');
        }
        if (!mounted) return;
        setState(() {
          _avatarUrl = url;
          _avatarLocalPath = null;
        });
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

  /// Throws on failure. An empty name or unparseable height/weight is
  /// omitted (= unchanged on the backend) rather than sent.
  Future<void> _persistProfile() async {
    // Read up front: a save can still land after the page is gone, and
    // Settings must see it even then.
    final profile = ref.read(profileProvider.notifier);
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
    profile.setProfile(result);
  }

  /// Onboarding's save before Continue. Returns whether it succeeded.
  Future<bool> _saveProfile() async {
    setState(() => _loading = true);
    try {
      await _persistProfile();
      return mounted;
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

  /// Skips the PATCH when nothing was edited this session.
  Future<void> _handleContinue() async {
    if (_isModified && !await _saveProfile()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyOutfitProfilePage()),
    );
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final canLeave = await confirmLeaveAfterAutoSave(
        context,
        _autoSave,
        onFlushingChanged: (saving) =>
            setState(() => _savingBeforeLeave = saving),
      );
      if (canLeave && mounted) Navigator.pop(context);
    } finally {
      _leaving = false;
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.account, onBack: _leave);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _autoSave,
      builder: (context, child) => PopScope(
        canPop: !_autoSave.hasPendingChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        extendBody: true,
        appBar: _buildAppBar(),
        bottomNavigationBar: widget.completingOnboarding
            ? BottomActionButton(
                label: _l10n.continueLabel,
                onPressed: _handleContinue,
                isLoading: _loading,
                enabled: _hasRequiredAboutYouFields,
              )
            : null,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatarSection(),
                        _buildFormFields(),
                        Builder(
                          builder: (bodyContext) => SizedBox(
                            height: _showsBottomActionButton
                                ? BottomActionButton.scrollClearance(
                                    bodyContext,
                                  )
                                : MediaQuery.paddingOf(context).bottom,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_savingBeforeLeave)
              Positioned.fill(
                child: LoadingOverlay(label: _l10n.savingEllipsis),
              ),
          ],
        ),
      ),
    );
  }

  bool get _showsBottomActionButton =>
      widget.completingOnboarding && _hasRequiredAboutYouFields && !_loading;

  /// The backend's OpenAPI example value "string" sometimes leaks through as
  /// a URL; treat it as "no avatar".
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
          size: _avatarSize,
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
      child: Focus(
        onFocusChange: (focused) {
          if (!focused) _onTextFieldBlur();
        },
        child: AppTextField(
          controller: _nameCtrl,
          hint: _l10n.enterYourNameHint,
          onChanged: (_) => _onEdited(typing: true),
          onSubmitted: (_) => _onTextFieldBlur(),
        ),
      ),
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
    final picked = await showSingleChoiceSheet<String>(
      context,
      title: _l10n.selectGenderHint,
      options: _genderOptions,
      selected: _selectedGender,
      labelOf: _genderDisplayLabel,
    );
    if (picked == null || !mounted) return;
    _selectGender(picked);
  }

  void _selectGender(String? value) {
    if (value == _selectedGender) return;
    setState(() => _selectedGender = value);
    _onEdited();
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
            : (d) {
                if (d == _selectedBirthDate) return;
                setState(() => _selectedBirthDate = d);
                _onEdited();
              },
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
              style: AppTextStyle.regular14.copyWith(
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
    if (result == null || !mounted || result.name == _homeLocation) return;
    setState(() => _homeLocation = result.name);
    _onEdited();
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
            onChanged: (_) => _onEdited(typing: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMeasurementField(
            controller: _weightCtrl,
            label: _l10n.weightHint,
            unit: 'kg',
            onChanged: (_) => _onEdited(typing: true),
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
      child: Focus(
        onFocusChange: (focused) {
          if (!focused) _onTextFieldBlur();
        },
        child: AppTextField(
          controller: controller,
          suffixText: unit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _decimalFormatters,
          onChanged: onChanged,
          onSubmitted: (_) => _onTextFieldBlur(),
        ),
      ),
    );
  }
}
