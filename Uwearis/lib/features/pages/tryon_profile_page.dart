import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../data/image_edit_result.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/overlays/inline_error_text.dart';
import '../widgets/common/section_title.dart';
import 'image_editor_page.dart';

/// Height/weight are always stored and saved as cm/kg (see
/// [ProfileService.updateMyProfile]) — this only controls which unit the
/// page displays and accepts input in. Not shared outside this page yet;
/// promote to a provider if another screen needs to display height/weight
/// in the user's preferred unit too.
enum _UnitSystem {
  metric,
  imperial;

  String get apiValue => this == metric ? 'metric' : 'imperial';

  static _UnitSystem fromApiValue(String? value) =>
      value == 'imperial' ? imperial : metric;
}

class TryonProfilePage extends StatefulWidget {
  const TryonProfilePage({super.key});

  @override
  State<TryonProfilePage> createState() => _TryonProfilePageState();
}

class _TryonProfilePageState extends State<TryonProfilePage> {
  static const double _cmPerInch = 2.54;
  static const double _kgPerLb = 0.45359237;

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
  String? _error;
  String? _fullBodyUrl;
  String? _fullBodyLocalPath;
  String? _faceRefUrl;
  String? _faceLocalPath;
  String _initialHeight = '';
  String _initialWeight = '';
  _UnitSystem _unitSystem = _UnitSystem.metric;
  _UnitSystem _initialUnitSystem = _UnitSystem.metric;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool get _isModified =>
      _heightCtrl.text != _initialHeight ||
      _weightCtrl.text != _initialWeight ||
      _unitSystem != _initialUnitSystem;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ProfileService().getMyProfile(),
        ProfileService().getBodyRef(),
        ProfileService().getFaceReference(),
      ]);
      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final fullBodyUrl = results[1] as String?;
      final faceRefUrl = results[2] as String?;
      setState(() {
        final h = profile['height'];
        final w = profile['weight'];
        if (h != null) _heightCtrl.text = (h as num).toStringAsFixed(0);
        if (w != null) _weightCtrl.text = (w as num).toStringAsFixed(0);
        _fullBodyUrl = fullBodyUrl;
        _faceRefUrl = faceRefUrl;
        _initialHeight = _heightCtrl.text;
        _initialWeight = _weightCtrl.text;
        _unitSystem = _UnitSystem.fromApiValue(
          profile['unit_system'] as String?,
        );
        _initialUnitSystem = _unitSystem;
        _syncImperialFromMetric();
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
      await ProfileService().updateMyProfile(
        height: h,
        weight: w,
        unitSystem: _unitSystem.apiValue,
      );
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
          aspectRatio: 3 / 4,
        ),
      ),
    );
    if (result == null || !mounted) return;
    // Confirmed without picking a new photo — imagePath is still the
    // original signed URL, not a local file. Nothing to upload.
    if (result.imagePath.startsWith('http')) return;
    setState(() => _fullBodyLocalPath = result.imagePath);
    await _uploadFullBody(result.imagePath);
  }

  Future<void> _changeFacePhoto() async {
    final result = await Navigator.push<ImageEditResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          initialPath: _faceLocalPath ?? _faceRefUrl,
          showAnalysis: false,
          aspectRatio: 3 / 4,
        ),
      ),
    );
    if (result == null || !mounted) return;
    // Confirmed without picking a new photo — imagePath is still the
    // original signed URL, not a local file. Nothing to upload.
    if (result.imagePath.startsWith('http')) return;
    setState(() => _faceLocalPath = result.imagePath);
    await _uploadFaceRef(result.imagePath);
  }

  Future<void> _uploadFullBody(String localPath) async {
    setState(() => _loading = true);
    try {
      final init = await ProfileService().bodyRefInitUpload();
      await ProfileService().putJpegToSignedUrl(init.uploadUrl, localPath);
      final url = await ProfileService().bodyRefComplete(
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

  Future<void> _uploadFaceRef(String localPath) async {
    setState(() => _loading = true);
    try {
      final init = await ProfileService().faceRefInitUpload();
      await ProfileService().putJpegToSignedUrl(init.uploadUrl, localPath);
      final url = await ProfileService().faceRefComplete(
        objectName: init.objectName,
      );
      if (mounted) {
        setState(() {
          _faceRefUrl = url;
          _faceLocalPath = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.aiModel);
  }

  bool get _showsBottomActionButton => _isModified && !_loading;

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
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          _showsBottomActionButton ? AppDimens.bottomActionBtnClearance : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) InlineErrorText(message: _error!),
            Text(
              _l10n.aiModelDescription,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDimens.sectionSpacing),
            _buildFaceReferenceCard(),
            const SizedBox(height: AppDimens.sectionSpacing),
            _buildBodyReferenceCard(),
            const SizedBox(height: AppDimens.sectionSpacing),
            _buildBodyMeasurementsCard(),
          ],
        ),
      ),
    );
  }

  /// One card shape for both Face and Body reference rows. [leading] (a
  /// compact photo/placeholder square) sits on the right; [title] and
  /// [subtitle] stack at the top-left and [action] follows below them
  /// (matching [leading]'s height via [IntrinsicHeight]), so the photo
  /// occupies the same vertical band as the title rather than starting
  /// below it. [onTap] only makes [action] itself tappable — the rest of
  /// the card (title, subtitle, photo) is inert, so a stray tap elsewhere
  /// doesn't accidentally open the photo picker.
  Widget _buildReferenceCard({
    required String title,
    required Widget leading,
    required String subtitle,
    required Widget action,
    required VoidCallback? onTap,
  }) {
    Widget tappableAction = action;
    if (onTap != null) {
      tappableAction = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: tappableAction,
      );
    }

    // Title+subtitle share the row with the thumbnail (rather than sitting
    // in a full-width strip above it) so the photo can occupy the same
    // vertical band as the title instead of only starting below it.
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SectionTitle(title),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                tappableAction,
              ],
            ),
          ),
          const SizedBox(width: 14),
          leading,
        ],
      ),
    );

    // Tighter on top/bottom/right now that the thumbnail sits on the
    // right — left stays at the normal card inset so the text column
    // doesn't hug that edge too.
    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: row,
    );
  }

  Widget _buildPhotoAction(ImageProvider? provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          provider != null ? _l10n.changePhotoAction : _l10n.addPhotoAction,
          style: AppTextStyle.semibold14.copyWith(color: AppColors.accent),
        ),
        Image.asset(
          'assets/images/page_arrow_right.png',
          width: 18,
          height: 18,
          color: AppColors.accent,
          colorBlendMode: BlendMode.srcIn,
        ),
      ],
    );
  }

  Widget _buildPhotoLeading(ImageProvider? provider, IconData placeholder) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        height: 128,
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Container(
                color: AppColors.placeholderSurface,
                child: Icon(
                  placeholder,
                  color: AppColors.placeholderIcon,
                  size: 28,
                ),
              ),
      ),
    );
  }

  Widget _buildFaceReferenceCard() {
    ImageProvider? provider;
    if (_faceLocalPath != null) {
      provider = FileImage(File(_faceLocalPath!));
    } else if (_faceRefUrl != null &&
        _faceRefUrl!.isNotEmpty &&
        _faceRefUrl != 'string') {
      provider = NetworkImage(_faceRefUrl!);
    }

    return _buildReferenceCard(
      title: _l10n.faceReferenceLabel,
      onTap: _loading ? null : _changeFacePhoto,
      leading: _buildPhotoLeading(provider, Icons.face_outlined),
      subtitle: _l10n.faceAppearanceSubtitle,
      action: _buildPhotoAction(provider),
    );
  }

  Widget _buildBodyReferenceCard() {
    ImageProvider? provider;
    if (_fullBodyLocalPath != null) {
      provider = FileImage(File(_fullBodyLocalPath!));
    } else if (_fullBodyUrl != null &&
        _fullBodyUrl!.isNotEmpty &&
        _fullBodyUrl != 'string') {
      provider = NetworkImage(_fullBodyUrl!);
    }

    return _buildReferenceCard(
      title: _l10n.bodyReferenceLabel,
      onTap: _loading ? null : _changeFullBodyPhoto,
      leading: _buildPhotoLeading(provider, Icons.accessibility_new_outlined),
      subtitle: _l10n.bodyProportionsSubtitle,
      action: _buildPhotoAction(provider),
    );
  }

  Widget _buildBodyMeasurementsCard() {
    return AppCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SectionTitle(_l10n.bodyMeasurementsLabel),
              const Spacer(),
              _buildUnitToggle(),
            ],
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _unitSystem == _UnitSystem.metric
              ? _buildMetricFields()
              : _buildImperialFields(),
        ],
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.placeholderSurface,
        borderRadius: BorderRadius.circular(8),
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
          child: _buildLabeledField(
            controller: _heightCtrl,
            label: _l10n.heightHint,
            unit: 'cm',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLabeledField(
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
          child: _buildLabeledField(
            controller: _heightFeetCtrl,
            label: _l10n.feetLabel,
            unit: 'ft',
            onChanged: (_) => _onImperialHeightChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildLabeledField(
            controller: _heightInchesCtrl,
            label: _l10n.inchesLabel,
            unit: 'in',
            onChanged: (_) => _onImperialHeightChanged(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLabeledField(
            controller: _weightLbCtrl,
            label: _l10n.weightHint,
            unit: 'lb',
            onChanged: (_) => _onImperialWeightChanged(),
          ),
        ),
      ],
    );
  }

  /// Matches Account page's name field: a small uppercase [FieldLabel]
  /// sitting above the box rather than a floating label inside it.
  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    required String unit,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label.toUpperCase()),
        const SizedBox(height: 8),
        AppTextField(
          controller: controller,
          suffixText: unit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _decimalFormatters,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
