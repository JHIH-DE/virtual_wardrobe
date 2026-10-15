import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garment_outfits_provider.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/auto_save_controller.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/signed_url.dart';
import '../../data/closet_analysis.dart';
import '../../data/garment.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/action_button.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/fields/labeled_field.dart';
import '../widgets/common/fields/picker_field.dart';
import '../widgets/common/fields/tappable_field_decorator.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/auto_save_prompts.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/page_sheet.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/overlays/save_changes_dialog.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_image.dart';
import '../widgets/garment/garment_outfit_ideas_card.dart';
import '../widgets/garment/garment_share_sheet.dart';
import 'add_outfit_page.dart';
import 'garment_outfits_page.dart';

enum _GarmentMenuAction { rename, share, delete }

class GarmentDetailsPage extends ConsumerStatefulWidget {
  final Garment initialGarment;
  final Map<String, dynamic>? initialAnalysisData;

  const GarmentDetailsPage({
    super.key,
    required this.initialGarment,
    this.initialAnalysisData,
  });

  @override
  ConsumerState<GarmentDetailsPage> createState() => _GarmentDetailsPageState();
}

class _GarmentDetailsPageState extends ConsumerState<GarmentDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _subCategory = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _isImageChanged = false;
  bool _isAnalyzing = false;
  bool _uploading = false;
  bool _openingAddOutfit = false;
  int? _id;
  String? _imagePathOrUrl;
  GarmentColor? _selectedColor;
  GarmentFit? _selectedFit;
  GarmentSilhouette? _selectedSilhouette;
  GarmentSleeveLength? _selectedSleeveLength;
  GarmentCropLength? _selectedCropLength;
  GarmentCategory _category = GarmentCategory.top;
  DateTime? _purchaseDate;
  Garment? _editingGarment;
  Map<String, dynamic>? _metaData;
  // ValueNotifiers, not setState fields: the analysis is shown in a modal
  // sheet (its own route) that this page's setState never rebuilds.
  final _closetAnalysis = ValueNotifier<ClosetAnalysis?>(null);
  // First run / cache read (full loading state). A re-run keeps showing the
  // old result, so it uses [_isRefreshingAnalysis] instead.
  final _isAnalyzingCloset = ValueNotifier<bool>(false);
  final _isRefreshingAnalysis = ValueNotifier<bool>(false);
  final _closetAnalysisError = ValueNotifier<String?>(null);
  late final Listenable _closetAnalysisState = Listenable.merge([
    _closetAnalysis,
    _isAnalyzingCloset,
    _isRefreshingAnalysis,
    _closetAnalysisError,
  ]);
  int? _outfitCount;

  /// Edit mode's name heading; only [_showRenameDialog] changes it.
  String? _name;

  // Edit mode only — add mode keeps the explicit Add to Closet button.
  late final AutoSaveController _autoSave = AutoSaveController(
    onSave: _persistEdits,
    onError: (e) => showAutoSaveErrorDialog(
      context,
      _autoSave,
      e,
      fallback: _l10n.garmentSaveFailed,
    ),
  );
  bool _leaving = false;
  bool _savingBeforeLeave = false;

  // Add mode only — gates Add to Closet and the leave prompt.
  bool _isModified = false;
  late String _initialName;
  late GarmentCategory _initialCategory;
  late String _initialSub;
  late String _initialBrand;
  late String _initialPrice;
  GarmentColor? _initialColor;
  GarmentFit? _initialFit;
  GarmentSilhouette? _initialSilhouette;
  GarmentSleeveLength? _initialSleeveLength;
  GarmentCropLength? _initialCropLength;
  DateTime? _initialDate;

  bool get _showFitField => garmentFitCategories.contains(_category);
  bool get _showSleeveLengthField =>
      garmentSleeveLengthCategories.contains(_category);
  bool get _showCropLengthField =>
      garmentCropLengthCategories.contains(_category);
  List<GarmentSilhouette> get _silhouetteOptions =>
      garmentSilhouettesByCategory[_category] ?? const [];

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _editingGarment = widget.initialGarment;
    _id = _editingGarment?.id;
    _imagePathOrUrl = _editingGarment?.imageUrl;
    _name = _editingGarment?.name;
    // Show loading during the async cache read rather than flashing the
    // "Analyze with AI" prompt.
    if (_id != null) _isAnalyzingCloset.value = true;

    _initialName = _editingGarment?.name ?? '';
    _initialCategory = _editingGarment?.category ?? GarmentCategory.top;
    _initialSub = _editingGarment?.subCategory ?? '';
    _initialBrand = _editingGarment?.brand ?? '';
    _initialPrice = _editingGarment?.price?.toString() ?? '';
    _initialColor = _tryParseGarmentColor(_editingGarment?.color);
    _initialFit = GarmentFitX.fromApiValue(_editingGarment?.fit);
    _initialSilhouette = GarmentSilhouetteX.fromApiValue(
      _editingGarment?.silhouette,
    );
    _initialSleeveLength = GarmentSleeveLengthX.fromApiValue(
      _editingGarment?.sleeveLength,
    );
    _initialCropLength = GarmentCropLengthX.fromApiValue(
      _editingGarment?.cropLength,
    );
    _initialDate = _editingGarment?.purchaseDate;

    if (_editingGarment != null) {
      _category = _editingGarment!.category;
      _subCategory.text = _editingGarment!.subCategory;
      _nameCtrl.text = _editingGarment!.name;
      _brandCtrl.text = _editingGarment!.brand ?? '';
      _priceCtrl.text = _editingGarment!.price?.toString() ?? '';
      _purchaseDate = _editingGarment!.purchaseDate;
      _selectedColor ??= _initialColor;
      _selectedFit ??= _initialFit;
      _selectedSilhouette ??= _initialSilhouette;
      _selectedSleeveLength ??= _initialSleeveLength;
      _selectedCropLength ??= _initialCropLength;
    }

    if (widget.initialAnalysisData != null) {
      _applyAnalysisData(widget.initialAnalysisData!);
    } else if (_id == null &&
        _imagePathOrUrl != null &&
        _imagePathOrUrl!.isNotEmpty) {
      _isImageChanged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runAIAnalysis(_imagePathOrUrl!);
      });
    }

    _nameCtrl.addListener(_checkModified);
    _subCategory.addListener(_checkModified);
    _brandCtrl.addListener(_checkModified);
    _priceCtrl.addListener(_checkModified);

    if (_id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFreshImage());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadCachedClosetAnalysis(),
      );
      _loadOutfitCount();
    }
  }

  int? get _garmentIdForOutfits =>
      _editingGarment?.garmentId ?? _editingGarment?.id;

  Future<void> _loadOutfitCount() async {
    final gid = _garmentIdForOutfits;
    if (gid == null) return;
    try {
      // Shared with GarmentOutfitsPage so opening it doesn't re-fetch.
      final outfits = await ref.read(garmentOutfitsProvider(gid).future);
      if (mounted) setState(() => _outfitCount = outfits.length);
    } catch (e) {
      // Secondary count — the tile stays hidden; no error UI.
      debugLog('Failed to load outfit count: $e');
    }
  }

  /// Re-fetches the garment if its signed image URL has expired, so the
  /// preview doesn't show a stale link.
  Future<void> _ensureFreshImage() async {
    final url = _imagePathOrUrl;
    if (_id == null || url == null || !url.startsWith('http')) return;
    if (!isSignedUrlExpired(url)) return;
    try {
      final fresh = await GarmentService().getGarment(_id!);
      if (mounted) setState(() => _imagePathOrUrl = fresh.imageUrl);
    } catch (_) {
      // Leave the existing URL; errorBuilder covers the fallback UI.
    }
  }

  void _checkModified() {
    if (!_isAddMode) return;
    final changed =
        _isImageChanged ||
        _nameCtrl.text != _initialName ||
        _category != _initialCategory ||
        _subCategory.text != _initialSub ||
        _brandCtrl.text != _initialBrand ||
        _priceCtrl.text != _initialPrice ||
        _selectedColor != _initialColor ||
        _selectedFit != _initialFit ||
        _selectedSilhouette != _initialSilhouette ||
        _selectedSleeveLength != _initialSleeveLength ||
        _selectedCropLength != _initialCropLength ||
        _purchaseDate != _initialDate;

    if (changed != _isModified) {
      setState(() => _isModified = changed);
    }
  }

  /// Add mode re-checks the Add to Closet gate; edit mode auto-saves
  /// (typing is debounced, everything else saves immediately).
  void _onEdited({bool typing = false}) {
    if (_isAddMode) {
      _checkModified();
    } else if (typing) {
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

  @override
  void dispose() {
    _autoSave.dispose();
    _nameCtrl.dispose();
    _subCategory.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _closetAnalysis.dispose();
    _isAnalyzingCloset.dispose();
    _isRefreshingAnalysis.dispose();
    _closetAnalysisError.dispose();
    super.dispose();
  }

  bool get _isAddMode => _id == null;

  String get _title {
    if (_isAddMode) return _l10n.quickActionAddClothing;
    if (_name != null && _name!.isNotEmpty) return _name!;
    return _l10n.details;
  }

  void _handleMenuAction(_GarmentMenuAction action) {
    switch (action) {
      case _GarmentMenuAction.rename:
        _showRenameDialog();
        break;
      case _GarmentMenuAction.share:
        _shareGarment();
        break;
      case _GarmentMenuAction.delete:
        _handleDelete();
        break;
    }
  }

  /// Uses the form's current values so an edit shows before it's saved.
  void _shareGarment() {
    final base = _editingGarment;
    if (base == null) return;
    final brand = _brandCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    showGarmentShareSheet(
      context,
      garment: base.copyWith(
        name: _nameCtrl.text.trim(),
        category: _category,
        subCategory: _subCategory.text.trim(),
        brand: brand.isEmpty ? null : brand,
        clearBrand: brand.isEmpty,
        price: price,
        clearPrice: price == null,
        purchaseDate: _purchaseDate,
        clearPurchaseDate: _purchaseDate == null,
      ),
    );
  }

  /// Saves through [_autoSave] (the PATCH carries the whole form) so a
  /// rename can't race a field save already in flight.
  Future<void> _showRenameDialog() async {
    final result = await showTextInputDialog(
      context,
      title: _l10n.renameGarment,
      hint: _l10n.clothingNameLabel,
      initialValue: _name ?? '',
    );
    if (result == null || !mounted || _editingGarment == null) return;

    setState(() {
      _name = result;
      _nameCtrl.text = result;
    });
    _onEdited();
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.deleteGarment,
        body: _l10n.deleteGarmentConfirmation,
        primaryLabel: _l10n.delete,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );

    if (confirm == true && _id != null) {
      try {
        await GarmentService().deleteGarment(_id!);
        if (!mounted) return;
        Navigator.pop(context, 'deleted');
      } on AuthExpiredException {
        if (!mounted) return;
        await AuthExpiredHandler.handle(context);
        return;
      } catch (e) {
        if (!mounted) return;
        debugLog('GarmentDetailsPage delete failed: $e');
        showErrorDialog(
          context,
          message: apiErrorMessage(
            _l10n,
            e,
            fallback: _l10n.garmentDeleteFailed,
          ),
        );
      }
    }
  }

  Future<bool> _confirmLeaveAddMode() async {
    if (!_isModified) return true;

    final choice = await showSaveChangesDialog(
      context,
      title: _l10n.unsavedChangesTitle,
      body: _l10n.unsavedChangesBody,
    );
    if (choice == SaveChangesChoice.save) {
      await _saveGarment();
      return false;
    }
    return choice == SaveChangesChoice.discard;
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final canLeave = _isAddMode
          ? await _confirmLeaveAddMode()
          : await confirmLeaveAfterAutoSave(
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
    return AppToolBar(
      title: _isAddMode ? _title : _l10n.clothingDetailsTitle,
      onBack: _leave,
      actions: [
        if (!_isAddMode)
          AppPopupMenu<_GarmentMenuAction>(
            variant: AppPopupMenuVariant.toolbar,
            onSelected: _handleMenuAction,
            items: [
              AppPopupMenu.item(
                value: _GarmentMenuAction.rename,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.icon,
                ),
                label: _l10n.rename,
              ),
              AppPopupMenu.item(
                value: _GarmentMenuAction.share,
                icon: const Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: AppColors.icon,
                ),
                label: _l10n.share,
              ),
              AppPopupMenu.item(
                value: _GarmentMenuAction.delete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.icon,
                ),
                label: _l10n.deleteGarment,
                isDestructive: true,
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _autoSave,
      builder: (context, child) => PopScope(
        // Not a hardcoded false — that would disable iOS swipe-back.
        canPop: _isAddMode ? !_isModified : !_autoSave.hasPendingChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        extendBody: true,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildForm(),
            if (_uploading)
              const Positioned.fill(child: Center(child: AppSpinner())),
            if (_savingBeforeLeave)
              Positioned.fill(
                child: LoadingOverlay(label: _l10n.savingEllipsis),
              ),
          ],
        ),
        bottomNavigationBar: _isAddMode
            ? BottomActionButton(
                label: _l10n.addToCloset,
                onPressed: _isModified ? _saveGarment : null,
                isLoading: _uploading,
              )
            : null,
      ),
    );
  }

  bool get _showsBottomActionButton => _isAddMode && _isModified && !_uploading;

  Widget _buildForm() {
    return Form(
      key: _formKey,
      // Edit mode has no submit step, so validate as the user types.
      autovalidateMode: _isAddMode
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: EdgeInsets.only(
          bottom: _showsBottomActionButton
              ? AppDimens.bottomActionBtnClearance
              : 20,
        ),
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _isAddMode
                ? _buildNameField()
                : Text(_title, style: AppTextStyle.bold20),
          ),
          const SizedBox(height: AppDimens.titleGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _imagePreview(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ActionButton(
              label: _l10n.viewClosetMatch,
              // Secondary while Add to Closet is the main action.
              variant: _isAddMode
                  ? ActionButtonVariant.secondary
                  : ActionButtonVariant.primary,
              leading: const Icon(
                Icons.auto_awesome_outlined,
                size: AppDimens.iconSmallSize,
              ),
              onPressed: _openClosetAnalysisSheet,
            ),
          ),
          _buildDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: const BoxDecoration(color: AppColors.pageBackground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showUsedInOutfits) ...[
            const SizedBox(height: AppDimens.sectionSpacing),
            _buildUsedInOutfitsTile(),
          ],
          const AppDivider(),
          _buildCategoryField(),
          const SizedBox(height: 20),
          _buildSubCategoryField(),
          const SizedBox(height: 20),
          _buildColorField(),
          if (_showFitField) ...[
            const SizedBox(height: 20),
            _buildFitField(),
            const SizedBox(height: 20),
            _buildSilhouetteField(),
          ],
          if (_showSleeveLengthField) ...[
            const SizedBox(height: 20),
            _buildSleeveLengthField(),
          ],
          if (_showCropLengthField) ...[
            const SizedBox(height: 20),
            _buildCropLengthField(),
          ],
          const SizedBox(height: 20),
          _buildBrandField(),
          const SizedBox(height: 20),
          _buildPriceField(),
          const SizedBox(height: 20),
          _buildPurchaseDateField(),
        ],
      ),
    );
  }

  // No label — it sits in the title position; the hint carries it.
  Widget _buildNameField() {
    return AppTextField(
      controller: _nameCtrl,
      hint: _l10n.nameTheClothingHint,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? _l10n.pleaseEnterNameError : null,
    );
  }

  Widget _buildCategoryField() {
    return _buildOptionField<GarmentCategory>(
      label: _l10n.clothingCategoryLabel,
      value: _category,
      options: GarmentCategory.values,
      labelOf: (c) => c.localizedLabel(context),
      onSelected: (c) {
        _category = c;
        _dropInapplicableAttributes();
      },
    );
  }

  /// [onSelected] runs inside one setState before [_onEdited], so a category
  /// change and the attributes it drops go out as one save.
  Widget _buildOptionField<T>({
    required String label,
    required T? value,
    required List<T> options,
    required String Function(T) labelOf,
    required void Function(T) onSelected,
  }) {
    return LabeledField(
      label: label,
      child: PickerField(
        text: value == null ? '' : labelOf(value),
        hint: _l10n.notSelected,
        onTap: () => _openOptionPicker<T>(
          title: label,
          value: value,
          options: options,
          labelOf: labelOf,
          onSelected: onSelected,
        ),
      ),
    );
  }

  Future<void> _openOptionPicker<T>({
    required String title,
    required T? value,
    required List<T> options,
    required String Function(T) labelOf,
    required void Function(T) onSelected,
  }) async {
    final picked = await showSingleChoiceSheet<T>(
      context,
      title: title,
      options: options,
      selected: value,
      labelOf: labelOf,
    );
    if (picked == null || picked == value || !mounted) return;
    setState(() => onSelected(picked));
    _onEdited();
  }

  /// Clears attributes [_category] doesn't support — a hidden field must not
  /// save a stale value, and a foreign silhouette 400s on PATCH
  /// (`INVALID_GARMENT_ATTRIBUTE`).
  void _dropInapplicableAttributes() {
    if (!_showFitField) _selectedFit = null;
    if (!_silhouetteOptions.contains(_selectedSilhouette)) {
      _selectedSilhouette = null;
    }
    if (!_showSleeveLengthField) _selectedSleeveLength = null;
    if (!_showCropLengthField) _selectedCropLength = null;
  }

  Widget _buildSubCategoryField() {
    return LabeledField(
      label: _l10n.productType,
      child: _savesOnBlur(
        AppTextField(
          controller: _subCategory,
          hint: _l10n.productTypeHint,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? _l10n.pleaseEnterProductTypeError
              : null,
          onChanged: (_) => _onEdited(typing: true),
          onSubmitted: (_) => _onTextFieldBlur(),
        ),
      ),
    );
  }

  Widget _buildColorField() {
    final selected = _selectedColor;
    return LabeledField(
      label: _l10n.color,
      child: TappableFieldDecorator(
        onTap: _openColorPickerSheet,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: selected?.color ?? Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1.2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selected?.localizedLabel(context) ?? _l10n.selectAColor,
              style: AppTextStyle.regular16.copyWith(
                color: selected == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          Image.asset(
            'assets/images/arrow_down.png',
            height: AppDimens.iconSmallSize,
          ),
        ],
      ),
    );
  }

  Widget _buildFitField() {
    return _buildOptionField<GarmentFit>(
      label: _l10n.fitLabel,
      value: _selectedFit,
      options: GarmentFit.values,
      labelOf: (f) => f.localizedLabel(context),
      onSelected: (f) => _selectedFit = f,
    );
  }

  Widget _buildSilhouetteField() {
    return _buildOptionField<GarmentSilhouette>(
      label: _l10n.silhouetteLabel,
      value: _selectedSilhouette,
      options: _silhouetteOptions,
      labelOf: (v) => v.localizedLabel(context),
      onSelected: (v) => _selectedSilhouette = v,
    );
  }

  Widget _buildSleeveLengthField() {
    return _buildOptionField<GarmentSleeveLength>(
      label: _l10n.sleeveLengthLabel,
      value: _selectedSleeveLength,
      options: GarmentSleeveLength.values,
      labelOf: (v) => v.localizedLabel(context),
      onSelected: (v) => _selectedSleeveLength = v,
    );
  }

  Widget _buildCropLengthField() {
    return _buildOptionField<GarmentCropLength>(
      label: _l10n.cropLengthLabel,
      value: _selectedCropLength,
      options: GarmentCropLength.values,
      labelOf: (v) => v.localizedLabel(context),
      onSelected: (v) => _selectedCropLength = v,
    );
  }

  Widget _buildBrandField() {
    return LabeledField(
      label: _l10n.brandOptionalLabel,
      child: _savesOnBlur(
        AppTextField(
          controller: _brandCtrl,
          hint: _l10n.brandHint,
          onChanged: (_) => _onEdited(typing: true),
          onSubmitted: (_) => _onTextFieldBlur(),
        ),
      ),
    );
  }

  Widget _buildPriceField() {
    return LabeledField(
      label: _l10n.priceOptionalLabel,
      child: _savesOnBlur(
        AppTextField(
          controller: _priceCtrl,
          hint: _l10n.priceHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _onEdited(typing: true),
          onSubmitted: (_) => _onTextFieldBlur(),
        ),
      ),
    );
  }

  Widget _savesOnBlur(Widget field) {
    return Focus(
      onFocusChange: (focused) {
        if (!focused) _onTextFieldBlur();
      },
      child: field,
    );
  }

  Widget _buildPurchaseDateField() {
    return LabeledField(
      label: _l10n.purchaseDateLabel,
      child: TappableFieldDecorator(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _purchaseDate ?? now,
            firstDate: DateTime(2000),
            lastDate: DateTime(now.year + 2),
          );
          if (picked != null && picked != _purchaseDate && mounted) {
            setState(() => _purchaseDate = picked);
            _onEdited();
          }
        },
        children: [
          Expanded(
            child: Text(
              _purchaseDate == null
                  ? _l10n.selectDate
                  : '${_purchaseDate!.year}/${_purchaseDate!.month}/${_purchaseDate!.day}',
              style: AppTextStyle.regular16.copyWith(
                color: _purchaseDate == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.calendar_today, size: 18, color: AppColors.icon),
        ],
      ),
    );
  }

  // ----------------------------
  // AI Analysis Logic
  // ----------------------------

  void _applyAnalysisData(
    Map<String, dynamic> analysisData, {
    String? processedImagePath,
  }) {
    if (processedImagePath != null) {
      _imagePathOrUrl = processedImagePath;
      _isImageChanged = true;
    }
    if (analysisData['name'] != null) {
      _nameCtrl.text = analysisData['name'].toString();
    }
    final String? catStr = analysisData['category']?.toString().toLowerCase();
    if (catStr != null) {
      for (var val in GarmentCategory.values) {
        if (val.name.toLowerCase() == catStr ||
            val.label.toLowerCase() == catStr) {
          _category = val;
          break;
        }
      }
    }
    if (analysisData['sub_category'] != null) {
      _subCategory.text = analysisData['sub_category'].toString();
    }
    final String? colorStr = analysisData['color']?.toString();
    if (colorStr != null) {
      _selectedColor = _tryParseGarmentColor(colorStr);
    }
    _selectedFit = GarmentFitX.fromApiValue(analysisData['fit']?.toString());
    _selectedSilhouette = GarmentSilhouetteX.fromApiValue(
      analysisData['silhouette']?.toString(),
    );
    _selectedSleeveLength = GarmentSleeveLengthX.fromApiValue(
      analysisData['sleeve_length']?.toString(),
    );
    _selectedCropLength = GarmentCropLengthX.fromApiValue(
      analysisData['crop_length']?.toString(),
    );
    _dropInapplicableAttributes();
    _metaData = analysisData;
    _checkModified();
  }

  Future<void> _runAIAnalysis(String imagePath) async {
    if (imagePath.startsWith('http')) return;
    try {
      setState(() => _isAnalyzing = true);
      final result = await GarmentService().analyzeGarment(imagePath);
      setState(() {
        _applyAnalysisData(
          result.metadata,
          processedImagePath: result.processedImagePath,
        );
        _isAnalyzing = false;
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      if (!mounted) return;
      debugLog('AI Analysis failed: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  /// Paid AI call, hence the synchronous guard. Add mode (no [_id]) runs a
  /// preview against the current form fields.
  Future<void> _runClosetAnalysis() async {
    if (_isAnalyzingCloset.value) return;
    _isAnalyzingCloset.value = true;
    _closetAnalysisError.value = null;
    try {
      final id = _id;
      final result = await GarmentService().closetAnalysis(
        id,
        id == null ? _closetAnalysisPreviewFields() : null,
      );
      if (!mounted) return;
      _closetAnalysis.value = result;
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } on ClosetAnalysisException catch (e) {
      if (!mounted) return;
      debugLog('closetAnalysis failed: ${e.errorCode}');
      _closetAnalysisError.value = e.errorCode == 'GARMENT_NOT_FOUND'
          ? _l10n.closetAnalysisGarmentNotFound
          : _l10n.closetAnalysisFailed;
    } catch (e) {
      if (!mounted) return;
      debugLog('closetAnalysis failed: $e');
      _closetAnalysisError.value = _l10n.closetAnalysisFailed;
    } finally {
      if (mounted) _isAnalyzingCloset.value = false;
    }
  }

  Future<void> _loadCachedClosetAnalysis() async {
    final id = _id;
    if (id == null) return;
    final cached = await GarmentService().cachedClosetAnalysis(id);
    if (!mounted) return;
    if (cached != null) _closetAnalysis.value = cached;
    _isAnalyzingCloset.value = false;
  }

  /// Writes a thumbnail's refreshed URL back into the persisted cache, which
  /// has no TTL and would otherwise keep serving the expired one.
  void _onOutfitIdeaImageRefreshed(int garmentId, String freshUrl) {
    final analysis = _closetAnalysis.value;
    final id = _id;
    if (analysis == null || id == null) return;
    final updated = _withRefreshedGarmentImage(analysis, garmentId, freshUrl);
    _closetAnalysis.value = updated;
    GarmentService().cacheClosetAnalysis(id, updated);
  }

  ClosetAnalysis _withRefreshedGarmentImage(
    ClosetAnalysis analysis,
    int garmentId,
    String freshUrl,
  ) {
    ClosetAnalysisGarment refreshIfMatch(ClosetAnalysisGarment g) {
      if (g.garmentId != garmentId) return g;
      return ClosetAnalysisGarment(
        garmentId: g.garmentId,
        category: g.category,
        name: g.name,
        imageUrl: freshUrl,
        isTarget: g.isTarget,
      );
    }

    return ClosetAnalysis(
      versatility: analysis.versatility,
      outfitIdeas: [
        for (final idea in analysis.outfitIdeas)
          ClosetAnalysisOutfitIdea(
            title: idea.title,
            garments: idea.garments.map(refreshIfMatch).toList(),
          ),
      ],
      similarGarments: analysis.similarGarments.map(refreshIfMatch).toList(),
    );
  }

  /// Unlike [_runClosetAnalysis], keeps the existing result on screen; a
  /// failure only shows a dialog and leaves the result and cache intact.
  Future<void> _refreshClosetAnalysis() async {
    if (_isRefreshingAnalysis.value || _closetAnalysis.value == null) return;
    _isRefreshingAnalysis.value = true;
    try {
      final id = _id;
      final result = await GarmentService().closetAnalysis(
        id,
        id == null ? _closetAnalysisPreviewFields() : null,
      );
      if (!mounted) return;
      _closetAnalysis.value = result;
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('closetAnalysis refresh failed: $e');
      showErrorDialog(context, message: _l10n.closetAnalysisFailed);
    } finally {
      if (mounted) _isRefreshingAnalysis.value = false;
    }
  }

  /// Starts the first run on open if there's no result yet. Closing the
  /// sheet mid-run doesn't cancel it.
  void _openClosetAnalysisSheet() {
    if (_closetAnalysis.value == null) _runClosetAnalysis();
    pageSheet<void>(
      context,
      title: _l10n.closetMatch,
      // Only once there's a result; a first-run failure retries from the
      // error state's own button.
      leading: ListenableBuilder(
        listenable: _closetAnalysisState,
        builder: (_, _) => _closetAnalysis.value == null
            ? const SizedBox.shrink()
            : PageSheetAction(
                icon: Icons.refresh,
                label: _l10n.analyzeAgain,
                busy: _isRefreshingAnalysis.value,
                onTap: _refreshClosetAnalysis,
              ),
      ),
      builder: (_) => ListenableBuilder(
        listenable: _closetAnalysisState,
        builder: (_, _) => Stack(
          children: [
            if (!_isAnalyzingCloset.value)
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 4),
                  child: _ClosetAnalysisSheetContent(
                    analysis: _closetAnalysis.value,
                    errorMessage: _closetAnalysisError.value,
                    onAnalyze: _runClosetAnalysis,
                    onGarmentTap: _openAiGarmentDetail,
                    // Add mode's garment isn't in the closet yet.
                    onCreateOutfit: _isAddMode ? null : _openAddOutfitFromIdea,
                    onGarmentImageRefreshed: _onOutfitIdeaImageRefreshed,
                    targetImageOverride: _isAddMode ? _imagePathOrUrl : null,
                  ),
                ),
              ),
            if (_isAnalyzingCloset.value || _isRefreshingAnalysis.value)
              Positioned.fill(
                child: LoadingOverlay(label: _l10n.analyzingEllipsis),
              ),
          ],
        ),
      ),
    );
  }

  /// The idea only carries ids, so resolve them against the closet;
  /// `.active` drops garments deleted since the analysis ran.
  Future<void> _openAddOutfitFromIdea(
    List<ClosetAnalysisGarment> ideaGarments,
  ) async {
    if (_openingAddOutfit) return;
    _openingAddOutfit = true;
    try {
      final closet = (await ref.read(garmentsProvider.future)).active;
      if (!mounted) return;
      final byId = {for (final g in closet) g.id: g};
      final garments = [for (final g in ideaGarments) ?byId[g.garmentId]];
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddOutfitPage(initialGarments: garments),
        ),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('_openAddOutfitFromIdea: failed to load garments: $e');
      showErrorDialog(context, message: _l10n.failedToLoadGarments);
    } finally {
      _openingAddOutfit = false;
    }
  }

  /// Looks in the loaded closet first (it includes soft-deleted garments);
  /// fetches only on a miss.
  Future<void> _openAiGarmentDetail(int garmentId) async {
    Garment? garment;
    for (final g in ref.read(garmentsProvider).value ?? const []) {
      if (g.id == garmentId) {
        garment = g;
        break;
      }
    }
    if (garment == null) {
      try {
        garment = await GarmentService().getGarment(
          garmentId,
          includeDeleted: true,
        );
      } on AuthExpiredException {
        if (!mounted) return;
        await AuthExpiredHandler.handle(context);
        return;
      } catch (e) {
        if (!mounted) return;
        debugLog('_openAiGarmentDetail: failed to load garment $garmentId: $e');
        return;
      }
    }
    if (!mounted) return;

    final restored = await GarmentDetailDialog.show(context, garment);
    if (restored == null || !mounted) return;
    ref.read(garmentsProvider.notifier).updateGarment(restored);
  }

  bool get _showUsedInOutfits =>
      !_isAddMode && _outfitCount != null && _outfitCount! > 0;

  Widget _buildUsedInOutfitsTile() {
    final count = _outfitCount!;

    return AppListCard(
      title: _l10n.usedInOutfits,
      onTap: _openUsedInOutfits,
      showArrow: true,
      leading: const Icon(Icons.checkroom_outlined, color: AppColors.icon),
      summary: _l10n.usedInOutfitsCount(count),
      child: const SizedBox.shrink(),
    );
  }

  void _openUsedInOutfits() {
    final gid = _garmentIdForOutfits;
    debugLog(
      'Used in Outfits tapped: garmentId=${_editingGarment?.garmentId} id=${_editingGarment?.id} → passing $gid',
    );
    if (gid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GarmentOutfitsPage(garmentId: gid)),
    );
  }

  void _openColorPickerSheet() {
    showPickerSheet(
      context,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PickerSheetHeader(
            _l10n.chooseColorTitle,
            trailing: TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (_selectedColor == null) return;
                setState(() => _selectedColor = null);
                _onEdited();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_l10n.clear),
            ),
          ),
          const SizedBox(height: 16),
          _buildColorGrid(),
        ],
      ),
    );
  }

  Widget _buildColorGrid() {
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        child: SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: GarmentColor.values
                .map((c) => _buildColorSwatch(c))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatch(GarmentColor c) {
    final isSelected = c == _selectedColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pop(context);
        if (c == _selectedColor) return;
        setState(() => _selectedColor = c);
        _onEdited();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, size: 20, color: c.preferredCheckColor)
            : null,
      ),
    );
  }

  Widget _imagePreview() {
    final img = _imagePathOrUrl;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            child: AspectRatio(
              aspectRatio: 1.1,
              // Not Image.network: it decodes while streaming, which can
              // render a torn frame on a flaky connection.
              child: GarmentImage(
                url: img,
                garmentId: _id,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        if (_isAnalyzing)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              child: LoadingOverlay(label: _l10n.analyzingClothingEllipsis),
            ),
          ),
      ],
    );
  }

  /// Add mode's Add to Closet — edit mode auto-saves via [_persistEdits].
  Future<void> _saveGarment() async {
    if (_uploading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _uploading = true);

    try {
      // The caller (GarmentUploadHelper.startAddClothingFlow) updates the
      // closet provider and shows the confirmation.
      final result = await _uploadNewGarment();
      if (!mounted) return;
      // Keep a preview analysis so reopening the garment doesn't lose it.
      final previewAnalysis = _closetAnalysis.value;
      if (previewAnalysis != null && result.id != null) {
        await GarmentService().cacheClosetAnalysis(
          result.id!,
          _retargetClosetAnalysis(previewAnalysis, result),
        );
        if (!mounted) return;
      }
      Navigator.pop(context, result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('GarmentDetailsPage._saveGarment failed: $e');
      if (mounted) {
        setState(() => _uploading = false);
        showErrorDialog(
          context,
          message: apiErrorMessage(_l10n, e, fallback: _l10n.garmentSaveFailed),
        );
      }
    }
  }

  /// [_autoSave]'s `onSave`; throws so the controller can offer a retry.
  /// Doesn't write the response back into the form — the user may already
  /// be typing the next change.
  Future<void> _persistEdits() async {
    final garments = ref.read(garmentsProvider.notifier);
    final updated = await _updateGarmentFields();
    _editingGarment = updated;
    garments.updateGarment(updated);
  }

  /// Add mode only — there's no endpoint to replace an existing photo.
  Future<Garment> _uploadNewGarment() async {
    final initDate = await GarmentService().initUpload();
    await GarmentService().putJpegToSignedUrl(
      initDate.uploadUrl,
      _imagePathOrUrl!,
    );
    final temp = Garment(
      uploadUrl: initDate.uploadUrl,
      objectName: initDate.objectName,
      category: _category,
      subCategory: _subCategory.text.trim(),
      name: _nameCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      color: _selectedColor?.label,
      fit: _selectedFit?.apiValue,
      silhouette: _selectedSilhouette?.apiValue,
      sleeveLength: _selectedSleeveLength?.apiValue,
      cropLength: _selectedCropLength?.apiValue,
      price: double.tryParse(_priceCtrl.text.trim()),
      purchaseDate: _purchaseDate,
    );
    // `/complete` reads these only from `metadata`, which must never be null
    // (it 500s). `crop_length` isn't nullable there, so unset is "".
    final metadata = <String, dynamic>{
      ...?_metaData,
      'fit': _selectedFit?.apiValue,
      'silhouette': _selectedSilhouette?.apiValue,
      'sleeve_length': _selectedSleeveLength?.apiValue,
      'crop_length': _selectedCropLength?.apiValue ?? '',
    };
    return GarmentService().completeUpload(temp, metadata);
  }

  /// Add mode's preview request body; fields the form can't edit
  /// (thickness, material, …) come from [_metaData].
  Map<String, dynamic> _closetAnalysisPreviewFields() {
    final brand = _brandCtrl.text.trim();
    return <String, dynamic>{
      ...?_metaData,
      'category': _category.apiValue,
      'sub_category': _subCategory.text.trim(),
      'name': _nameCtrl.text.trim(),
      'brand': brand.isEmpty ? null : brand,
      'color': _selectedColor?.label,
      'fit': _selectedFit?.apiValue,
      'silhouette': _selectedSilhouette?.apiValue,
      'sleeve_length': _selectedSleeveLength?.apiValue,
      'crop_length': _selectedCropLength?.apiValue,
    };
  }

  /// Points a preview's placeholder target (id 0, empty imageUrl) at the
  /// saved garment. Similar garments never include the target.
  ClosetAnalysis _retargetClosetAnalysis(
    ClosetAnalysis analysis,
    Garment saved,
  ) {
    ClosetAnalysisGarment retarget(ClosetAnalysisGarment g) {
      if (!g.isTarget) return g;
      return ClosetAnalysisGarment(
        garmentId: saved.id!,
        category: saved.category,
        name: saved.name,
        imageUrl: saved.imageUrl ?? '',
        isTarget: true,
      );
    }

    return ClosetAnalysis(
      versatility: analysis.versatility,
      outfitIdeas: [
        for (final idea in analysis.outfitIdeas)
          ClosetAnalysisOutfitIdea(
            title: idea.title,
            garments: idea.garments.map(retarget).toList(),
          ),
      ],
      similarGarments: analysis.similarGarments,
    );
  }

  Future<Garment> _updateGarmentFields() async {
    final saved = _editingGarment!;
    final name = _nameCtrl.text.trim();
    final subCategory = _subCategory.text.trim();
    final brand = _brandCtrl.text.trim();
    final priceText = _priceCtrl.text.trim();
    final price = double.tryParse(priceText);
    final updated = saved.copyWith(
      // An invalid field keeps its saved value instead of being sent.
      name: name.isEmpty ? saved.name : name,
      category: _category,
      subCategory: subCategory.isEmpty ? saved.subCategory : subCategory,
      brand: brand.isEmpty ? null : brand,
      clearBrand: brand.isEmpty,
      color: _selectedColor?.label,
      clearColor: _selectedColor == null,
      fit: _selectedFit?.apiValue,
      clearFit: _selectedFit == null,
      silhouette: _selectedSilhouette?.apiValue,
      clearSilhouette: _selectedSilhouette == null,
      sleeveLength: _selectedSleeveLength?.apiValue,
      clearSleeveLength: _selectedSleeveLength == null,
      cropLength: _selectedCropLength?.apiValue,
      clearCropLength: _selectedCropLength == null,
      price: price,
      clearPrice: priceText.isEmpty,
      purchaseDate: _purchaseDate,
      clearPurchaseDate: _purchaseDate == null,
    );
    return GarmentService().updateGarment(updated);
  }

  GarmentColor? _tryParseGarmentColor(String? colorText) {
    if (colorText == null) return null;
    final normalized = colorText.trim().toLowerCase();
    for (final c in GarmentColor.values) {
      if (normalized.contains(c.name.toLowerCase()) ||
          normalized.contains(c.label.toLowerCase())) {
        return c;
      }
    }
    return null;
  }
}

/// Versatility level, outfit ideas and similar garments. The prompt/error
/// states are fallbacks — the sheet normally opens into a loading overlay.
class _ClosetAnalysisSheetContent extends StatelessWidget {
  final ClosetAnalysis? analysis;
  final String? errorMessage;
  final VoidCallback onAnalyze;
  final void Function(int garmentId) onGarmentTap;

  /// Each idea's "Try It On" button; null hides it.
  final void Function(List<ClosetAnalysisGarment> garments)? onCreateOutfit;

  final void Function(int garmentId, String freshUrl) onGarmentImageRefreshed;

  /// Add mode's local photo — the preview target has no image URL.
  final String? targetImageOverride;

  const _ClosetAnalysisSheetContent({
    required this.analysis,
    required this.errorMessage,
    required this.onAnalyze,
    required this.onGarmentTap,
    this.onCreateOutfit,
    required this.onGarmentImageRefreshed,
    this.targetImageOverride,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (errorMessage != null) return _buildError(l10n, errorMessage!);
    if (analysis == null) return _buildPrompt(l10n);
    return _buildResult(context, l10n, analysis!);
  }

  Widget _buildPrompt(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.versatilityDescription, style: AppTextStyle.insightCardBody),
        const SizedBox(height: 8),
        Align(
          child: AccentPillButton(
            label: l10n.analyzeWithAi,
            icon: Icons.auto_awesome_outlined,
            onPressed: onAnalyze,
          ),
        ),
      ],
    );
  }

  Widget _buildError(AppLocalizations l10n, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppTextStyle.regular14.copyWith(color: AppColors.error),
        ),
        const SizedBox(height: 8),
        Align(
          child: AccentPillButton(
            label: l10n.analyzeAgain,
            icon: Icons.refresh,
            onPressed: onAnalyze,
          ),
        ),
      ],
    );
  }

  Widget _buildResult(
    BuildContext context,
    AppLocalizations l10n,
    ClosetAnalysis analysis,
  ) {
    final ideas = analysis.outfitIdeas;
    final similar = analysis.similarGarments;
    final headingStyle = AppTextStyle.bold18.copyWith(
      color: AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVersatilitySection(context, l10n, analysis.versatility),
        // Empty when the closet can't support them — omit the section.
        if (ideas.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionTitle(l10n.outfitIdeasHeading, style: headingStyle),
          const SizedBox(height: 10),
          for (var i = 0; i < ideas.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.cardSpacing),
            GarmentOutfitIdeasCard(
              title: l10n.outfitIdeaNumber(i + 1),
              onTryOn: switch (onCreateOutfit) {
                final onCreate? => () => onCreate(ideas[i].garments),
                null => null,
              },
              child: _buildGarmentThumbRow(
                ideas[i].garments,
                isOutfit: true,
                onGarmentTap: onGarmentTap,
                targetImageOverride: targetImageOverride,
                onImageUrlRefreshed: onGarmentImageRefreshed,
              ),
            ),
          ],
        ],
        if (similar.isNotEmpty) ...[
          const AppDivider(topSpacing: 20, bottomSpacing: 16),
          SectionTitle(l10n.similarInClosetHeading, style: headingStyle),
          const SizedBox(height: 10),
          _buildGarmentThumbRow(
            similar,
            onGarmentTap: onGarmentTap,
            targetImageOverride: targetImageOverride,
            onImageUrlRefreshed: onGarmentImageRefreshed,
          ),
        ],
      ],
    );
  }

  Widget _buildVersatilitySection(
    BuildContext context,
    AppLocalizations l10n,
    ClosetAnalysisVersatility versatility,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${versatility.level}',
                    style: AppTextStyle.bold24.copyWith(
                      fontSize: 52,
                      height: 1,
                      color: AppColors.accent,
                    ),
                  ),
                  TextSpan(
                    text: '/${_VersatilityLevelBar.segments}',
                    style: AppTextStyle.bold24.copyWith(
                      fontSize: 34,
                      height: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.borderSubtle,
            ),
            Expanded(
              child: Text(
                versatility.label.localizedLabel(context),
                style: AppTextStyle.bold20.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _VersatilityLevelBar(level: versatility.level),
      ],
    );
  }

  /// [isOutfit]: "+" separators and no borders except the target's.
  Widget _buildGarmentThumbRow(
    List<ClosetAnalysisGarment> garments, {
    bool isOutfit = false,
    void Function(int garmentId)? onGarmentTap,
    String? targetImageOverride,
    void Function(int garmentId, String freshUrl)? onImageUrlRefreshed,
  }) {
    return SizedBox(
      height: _AiGarmentThumb.size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: garments.length,
        separatorBuilder: (_, _) => isOutfit
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.add,
                  size: AppDimens.iconSmallSize,
                  color: AppColors.hintText,
                ),
              )
            : const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = garments[i];
          // The preview target (id 0) isn't a real garment yet.
          final canOpen = onGarmentTap != null && g.garmentId > 0;
          return _AiGarmentThumb(
            garment: g,
            bordered: !isOutfit,
            targetImageOverride: targetImageOverride,
            onTap: canOpen ? () => onGarmentTap(g.garmentId) : null,
            onImageUrlRefreshed: onImageUrlRefreshed,
          );
        },
      ),
    );
  }
}

class _VersatilityLevelBar extends StatelessWidget {
  final int level;

  const _VersatilityLevelBar({required this.level});

  static const int segments = 10;

  @override
  Widget build(BuildContext context) {
    final filled = level.clamp(0, segments);
    return Row(
      children: [
        for (var i = 0; i < segments; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < filled ? AppColors.accent : AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The target garment gets the same outline as a selected GarmentCard.
class _AiGarmentThumb extends StatefulWidget {
  final ClosetAnalysisGarment garment;
  final VoidCallback? onTap;
  final bool bordered;
  final String? targetImageOverride;
  final void Function(int garmentId, String freshUrl)? onImageUrlRefreshed;

  const _AiGarmentThumb({
    required this.garment,
    this.onTap,
    this.bordered = true,
    this.targetImageOverride,
    this.onImageUrlRefreshed,
  });

  static const double size = 70;

  @override
  State<_AiGarmentThumb> createState() => _AiGarmentThumbState();
}

class _AiGarmentThumbState extends State<_AiGarmentThumb> {
  /// Set when the cached URL is already expired: fetch a fresh one first
  /// instead of flashing the broken-image icon.
  Future<String?>? _preRefresh;

  @override
  void initState() {
    super.initState();
    _maybeStartPreRefresh();
  }

  @override
  void didUpdateWidget(covariant _AiGarmentThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.garment.imageUrl != oldWidget.garment.imageUrl) {
      _maybeStartPreRefresh();
    }
  }

  void _maybeStartPreRefresh() {
    final id = widget.garment.garmentId;
    final url = widget.garment.imageUrl;
    final knownExpired =
        id > 0 &&
        url.isNotEmpty &&
        url.startsWith('http') &&
        isSignedUrlExpired(url);
    _preRefresh = knownExpired ? _fetchFreshUrl(id, url) : null;
  }

  Future<String?> _fetchFreshUrl(int id, String staleUrl) async {
    try {
      final fresh = await GarmentService().getGarment(id, includeDeleted: true);
      final freshUrl = fresh.imageUrl;
      if (freshUrl != null && freshUrl.isNotEmpty && freshUrl != staleUrl) {
        widget.onImageUrlRefreshed?.call(id, freshUrl);
        return freshUrl;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildImage(String? url) {
    final garment = widget.garment;
    return GarmentImage(
      url: url,
      garmentId: garment.garmentId > 0 ? garment.garmentId : null,
      // Width only — pinning both forces a non-square source to decode
      // squashed into a square.
      memCacheWidth: 160,
      fit: BoxFit.contain,
      onUrlRefreshed: widget.onImageUrlRefreshed == null
          ? null
          : (_, newUrl) =>
                widget.onImageUrlRefreshed!(garment.garmentId, newUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final garment = widget.garment;
    final preRefresh = _preRefresh;
    final Widget image;
    if (preRefresh != null) {
      image = FutureBuilder<String?>(
        future: preRefresh,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          final resolved = snapshot.data;
          return _buildImage(
            resolved != null && resolved.isNotEmpty
                ? resolved
                : garment.imageUrl,
          );
        },
      );
    } else {
      image = _buildImage(
        garment.isTarget && garment.imageUrl.isEmpty
            ? widget.targetImageOverride
            : garment.imageUrl,
      );
    }
    final thumb = Container(
      width: _AiGarmentThumb.size,
      height: _AiGarmentThumb.size,
      padding: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: widget.bordered || garment.isTarget
            ? Border.all(
                color: garment.isTarget
                    ? AppColors.borderStrong
                    : AppColors.borderSubtle,
                width: garment.isTarget ? 1.5 : 1,
              )
            : null,
      ),
      child: image,
    );
    if (widget.onTap == null) return thumb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: thumb,
    );
  }
}
