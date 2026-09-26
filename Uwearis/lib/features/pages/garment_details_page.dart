import 'package:cached_network_image/cached_network_image.dart';
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
import '../../core/utils/debug_log.dart';
import '../../core/utils/image_cache_bust.dart';
import '../../core/utils/signed_url.dart';
import '../../data/closet_analysis.dart';
import '../../data/garment.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_icon_button.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/fields/labeled_field.dart';
import '../widgets/common/fields/picker_field.dart';
import '../widgets/common/fields/tappable_field_decorator.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/overlays/save_changes_dialog.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_image.dart';
import '../widgets/garment/garment_share_sheet.dart';
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
  int? _id;
  String? _imagePathOrUrl;
  GarmentColor? _selectedColor;
  GarmentFit? _selectedFit;
  GarmentCategory _category = GarmentCategory.top;
  DateTime? _purchaseDate;
  Garment? _editingGarment;
  Map<String, dynamic>? _metaData;
  // Closet-analysis result — null shows the insight card's prompt +
  // "Analyze with AI" button; set once the user runs _runClosetAnalysis, or
  // restored in initState from GarmentService's persisted cache if this
  // garment has ever been analyzed (see _loadCachedClosetAnalysis). Only
  // reachable once the garment has an [_id] — an in-progress Add Clothing
  // draft isn't in the closet yet for the backend to analyze.
  ClosetAnalysis? _closetAnalysis;
  // Drives the insight card's *initial* loading state — the first-ever
  // "Analyze with AI" run, and (reused, since it looks identical) the brief
  // async cache read in initState. [_isRefreshingAnalysis] is the separate
  // in-flight flag for re-analyzing once a result already exists, since
  // that must keep showing the old result rather than this full-body
  // loading state — see _refreshClosetAnalysis.
  bool _isAnalyzingCloset = false;
  bool _isRefreshingAnalysis = false;
  String? _closetAnalysisError;
  int? _outfitCount;

  /// The App Bar title's source of truth — mirrors
  /// `OutfitDetailsPage._name`. Only [_showRenameDialog] updates this
  /// (not [_nameCtrl] directly), so the title doesn't flicker through
  /// every uncommitted keystroke in the form's Name field; a full-form
  /// save via the bottom button pops this page anyway, so it never needs
  /// to reflect that path.
  String? _name;

  bool _isModified = false;
  late String _initialName;
  late GarmentCategory _initialCategory;
  late String _initialSub;
  late String _initialBrand;
  late String _initialPrice;
  GarmentColor? _initialColor;
  GarmentFit? _initialFit;
  DateTime? _initialDate;

  bool get _showFitField => garmentFitCategories.contains(_category);

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _editingGarment = widget.initialGarment;
    _id = _editingGarment?.id;
    _imagePathOrUrl = _editingGarment?.imageUrl;
    _name = _editingGarment?.name;
    // A persisted cache read is async (SharedPreferences), so it can't
    // resolve within initState itself — reuse the insight card's normal
    // "Analyzing…" loading state for that brief window instead of flashing
    // the "Analyze with AI" prompt right before it's (usually) immediately
    // replaced by a cached result. See _loadCachedClosetAnalysis.
    if (_id != null) _isAnalyzingCloset = true;

    // Snapshot initial values for later change detection
    _initialName = _editingGarment?.name ?? '';
    _initialCategory = _editingGarment?.category ?? GarmentCategory.top;
    _initialSub = _editingGarment?.subCategory ?? '';
    _initialBrand = _editingGarment?.brand ?? '';
    _initialPrice = _editingGarment?.price?.toString() ?? '';
    _initialColor = _tryParseGarmentColor(_editingGarment?.color);
    _initialFit = GarmentFitX.fromApiValue(_editingGarment?.fit);
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
      // Same list GarmentOutfitsPage shows (general outfits only) — shared
      // via garmentOutfitsProvider so opening that page doesn't re-fetch.
      final outfits = await ref.read(garmentOutfitsProvider(gid).future);
      if (mounted) setState(() => _outfitCount = outfits.length);
    } catch (e) {
      // Tile just stays in its loading state; not worth surfacing an error
      // for a secondary count that the user can still reach via the tap —
      // but still log it, so a silent failure here doesn't go unnoticed.
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
    final changed =
        _isImageChanged ||
        _nameCtrl.text != _initialName ||
        _category != _initialCategory ||
        _subCategory.text != _initialSub ||
        _brandCtrl.text != _initialBrand ||
        _priceCtrl.text != _initialPrice ||
        _selectedColor != _initialColor ||
        _selectedFit != _initialFit ||
        _purchaseDate != _initialDate;

    if (changed != _isModified) {
      setState(() => _isModified = changed);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subCategory.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // No ID means Add mode
  bool get _isAddMode => _id == null;

  /// Mirrors `OutfitDetailsPage._title` — App Bar title, sourced from
  /// [_name] rather than [_nameCtrl] (see [_name]'s doc comment).
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

  /// Opens the share sheet — a small card preview of this garment that
  /// rasterizes to a PNG for the system share sheet. Only reachable in edit
  /// mode (the ⋮ menu is hidden while adding). Reflects the form's current
  /// name/category so a just-made edit shows even before it's saved.
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

  /// Instant rename, independent of the full-form Save button — mirrors
  /// `OutfitDetailsPage._showRenameDialog`. Unlike the rest of this
  /// form's fields (batched into one `updateGarment` PATCH on Save), this
  /// persists immediately via the same endpoint with just the name
  /// changed, then syncs [_nameCtrl]/[_initialName] so the bottom Save
  /// button's "unsaved changes" detection doesn't treat the rename itself
  /// as a pending edit.
  Future<void> _showRenameDialog() async {
    final result = await showTextInputDialog(
      context,
      title: _l10n.renameGarment,
      hint: _l10n.clothingNameLabel,
      initialValue: _name ?? '',
    );

    if (result == null || !mounted) return;
    if (_editingGarment == null) return;

    try {
      final updated = await GarmentService().updateGarment(
        _editingGarment!.copyWith(name: result),
      );
      if (!mounted) return;
      setState(() {
        _editingGarment = updated;
        _name = updated.name;
        // _initialName must be updated *before* _nameCtrl.text: assigning the
        // controller's text fires the _checkModified listener synchronously,
        // and if it still saw the old _initialName it would latch
        // _isModified = true and the unsaved-changes prompt would then fire
        // on leave even though the rename is already persisted.
        _initialName = updated.name;
        _nameCtrl.text = updated.name;
      });
      ref.read(garmentsProvider.notifier).updateGarment(updated);
    } on AuthExpiredException {
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('GarmentDetailsPage rename failed: $e');
      if (mounted) {
        showErrorDialog(
          context,
          message: apiErrorMessage(
            _l10n,
            e,
            fallback: _l10n.garmentRenameFailed,
          ),
        );
      }
    }
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

  Future<bool> _onWillPop() async {
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

  AppToolBar _buildAppBar() {
    return AppToolBar(
      // Add mode: "Add Clothing" in the toolbar (the name field takes its
      // old spot below). Edit mode: "Clothing Details", matching Trip/Outfit
      // Details' fixed AppBar title — the garment's own name still shows as
      // its own block below the app bar (see [_buildForm]).
      title: _isAddMode ? _title : _l10n.clothingDetailsTitle,
      onBack: () async {
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      actions: [
        if (!_isAddMode)
          AppPopupMenu<_GarmentMenuAction>(
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
    return PopScope(
      // Only intercept when there's actually something to lose — same
      // condition _onWillPop already checks. A hardcoded false disables the
      // iOS edge-swipe-back gesture outright (matches OutfitDetailsPage's
      // `canPop: !widget.isNew || _saved`, not TripDetailsPage's lack of a
      // PopScope at all — this page always has unsaved-changes to guard).
      canPop: !_isModified,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (!shouldPop) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        extendBody: true,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildForm(),
            if (_uploading)
              const Positioned.fill(child: Center(child: AppSpinner())),
          ],
        ),
        // Save button pinned to the bottom
        bottomNavigationBar: BottomActionButton(
          label: _isAddMode ? _l10n.addToCloset : _l10n.save,
          onPressed: _isModified ? _saveGarment : null,
          isLoading: _uploading,
        ),
      ),
    );
  }

  bool get _showsBottomActionButton => _isModified && !_uploading;

  Widget _buildForm() {
    return Form(
      key: _formKey,
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
            // Add mode: the name input sits here (title moved to the toolbar).
            // Edit mode: the garment's name as a heading.
            child: _isAddMode
                ? _buildNameField()
                : Text(_title, style: AppTextStyle.bold20),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: AppDivider(topSpacing: 12, bottomSpacing: 16),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _imagePreview(),
          ),
          if (!_isAddMode) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _UwearisAiAnalysisCard(
                analysis: _closetAnalysis,
                isAnalyzing: _isAnalyzingCloset,
                isRefreshing: _isRefreshingAnalysis,
                errorMessage: _closetAnalysisError,
                onAnalyze: _runClosetAnalysis,
                onRefresh: _refreshClosetAnalysis,
                onGarmentTap: _openAiGarmentDetail,
              ),
            ),
          ],
          const SizedBox(height: AppDimens.sectionSpacing),
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
          if (!_isAddMode) _buildUsedInOutfitsTile(),
          const AppDivider(),
          // In Add Mode the name field lives up top where the title block
          // otherwise sits (see _buildForm). Editing an existing garment has
          // no inline name field at all — it renames via the App Bar's ⋮ ▸
          // Rename dialog (see _showRenameDialog).
          _buildCategoryField(),
          const SizedBox(height: 20),
          _buildSubCategoryField(),
          const SizedBox(height: 20),
          _buildColorField(),
          if (_showFitField) ...[const SizedBox(height: 20), _buildFitField()],
          const SizedBox(height: 20),
          _buildBrandField(),
          const SizedBox(height: 20),
          _buildPriceField(),
          const SizedBox(height: 20),
          _buildPurchaseDateSection(),
        ],
      ),
    );
  }

  // No FieldLabel — it sits where the page title used to be, so "NAME" above
  // it would read as a stray label; the hint carries the affordance.
  Widget _buildNameField() {
    return AppTextField(
      controller: _nameCtrl,
      hint: _l10n.nameTheClothingHint,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? _l10n.pleaseEnterNameError : null,
    );
  }

  Widget _buildCategoryField() {
    return LabeledField(
      label: _l10n.clothingCategoryLabel,
      child: PickerField(
        text: _category.localizedLabel(context),
        onTap: _openCategoryPicker,
      ),
    );
  }

  Future<void> _openCategoryPicker() async {
    await showPickerSheet<void>(
      context,
      builder: (sheetContext) => RadioGroup<GarmentCategory>(
        groupValue: _category,
        onChanged: (v) {
          if (v != null) _applyCategoryChange(v);
          Navigator.pop(sheetContext);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PickerSheetHeader(_l10n.clothingCategoryLabel),
            for (final c in GarmentCategory.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.localizedLabel(context),
                  style: c == _category
                      ? AppTextStyle.bold16
                      : AppTextStyle.regular16,
                ),
                trailing: Radio<GarmentCategory>(
                  value: c,
                  activeColor: AppColors.accent,
                ),
                onTap: () {
                  _applyCategoryChange(c);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Fit only makes sense for garments with a body-shape silhouette
  /// ([garmentFitCategories]), so a category switch away from those clears
  /// any previously-picked fit rather than silently saving a stale value
  /// for a category where the field is now hidden.
  void _applyCategoryChange(GarmentCategory category) {
    setState(() {
      _category = category;
      if (!_showFitField) _selectedFit = null;
    });
    _checkModified();
  }

  Widget _buildSubCategoryField() {
    return LabeledField(
      label: _l10n.productType,
      child: AppTextField(
        controller: _subCategory,
        hint: _l10n.productTypeHint,
        validator: (v) => (v == null || v.trim().isEmpty)
            ? _l10n.pleaseEnterProductTypeError
            : null,
      ),
    );
  }

  Widget _buildColorField() {
    return LabeledField(label: _l10n.color, child: _colorPicker());
  }

  Widget _buildFitField() {
    return LabeledField(label: _l10n.fitLabel, child: _fitSlider());
  }

  Widget _buildBrandField() {
    return LabeledField(
      label: _l10n.brandOptionalLabel,
      child: AppTextField(controller: _brandCtrl, hint: _l10n.brandHint),
    );
  }

  Widget _buildPriceField() {
    return LabeledField(
      label: _l10n.priceOptionalLabel,
      child: AppTextField(
        controller: _priceCtrl,
        hint: _l10n.priceHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  Widget _buildPurchaseDateSection() {
    return LabeledField(
      label: _l10n.purchaseDateLabel,
      child: _purchaseDateField(),
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

  /// Runs the AI closet analysis (versatility level + outfit ideas + similar
  /// garments) for this already-saved garment — the insight card's "Analyze
  /// with AI" / "Analyze Again" button. Synchronous re-entrancy guard — it's
  /// a paid AI call. Only reachable once [_id] is set (see [_closetAnalysis]
  /// doc comment).
  Future<void> _runClosetAnalysis() async {
    final id = _id;
    if (id == null || _isAnalyzingCloset) return;
    setState(() {
      _isAnalyzingCloset = true;
      _closetAnalysisError = null;
    });
    try {
      final result = await GarmentService().closetAnalysis(id);
      if (!mounted) return;
      setState(() => _closetAnalysis = result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } on ClosetAnalysisException catch (e) {
      if (!mounted) return;
      debugLog('closetAnalysis failed: ${e.errorCode}');
      setState(() {
        _closetAnalysisError = e.errorCode == 'GARMENT_NOT_FOUND'
            ? _l10n.closetAnalysisGarmentNotFound
            : _l10n.closetAnalysisFailed;
      });
    } catch (e) {
      if (!mounted) return;
      debugLog('closetAnalysis failed: $e');
      setState(() => _closetAnalysisError = _l10n.closetAnalysisFailed);
    } finally {
      if (mounted) setState(() => _isAnalyzingCloset = false);
    }
  }

  /// Restores a previously-persisted closet-analysis result on page open —
  /// see [GarmentService.cachedClosetAnalysis]'s own doc comment for the
  /// caching policy (no TTL; the user decides when to re-run it). A cache
  /// miss just falls through to the normal "Analyze with AI" prompt.
  Future<void> _loadCachedClosetAnalysis() async {
    final id = _id;
    if (id == null) return;
    final cached = await GarmentService().cachedClosetAnalysis(id);
    if (!mounted) return;
    setState(() {
      if (cached != null) _closetAnalysis = cached;
      _isAnalyzingCloset = false;
    });
  }

  /// Re-runs the closet analysis for a garment that already has a result —
  /// the insight card's header refresh action. Unlike [_runClosetAnalysis],
  /// this keeps showing the *existing* [_closetAnalysis] for the whole
  /// request: a failure leaves it (and its persisted cache entry) exactly
  /// as it was, with just an error dialog instead of replacing the card
  /// with the full error state — refreshing re-generates, it never deletes.
  /// Synchronous re-entrancy guard, same reasoning as [_runClosetAnalysis].
  Future<void> _refreshClosetAnalysis() async {
    final id = _id;
    if (id == null || _isRefreshingAnalysis || _closetAnalysis == null) {
      return;
    }
    setState(() => _isRefreshingAnalysis = true);
    try {
      final result = await GarmentService().closetAnalysis(id);
      if (!mounted) return;
      setState(() => _closetAnalysis = result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('closetAnalysis refresh failed: $e');
      showErrorDialog(context, message: _l10n.closetAnalysisFailed);
    } finally {
      if (mounted) setState(() => _isRefreshingAnalysis = false);
    }
  }

  /// Opens [GarmentDetailDialog] for an outfit idea's garment — same dialog
  /// Outfit Details' own garment list uses (see `_openGarmentDetail` there).
  /// Resolves [garmentId] against the already-loaded closet first (cheap,
  /// and already includes soft-deleted entries — see `GarmentService.
  /// getGarments`'s own doc comment); falls back to a direct fetch only if
  /// it isn't there yet.
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

  Widget _buildUsedInOutfitsTile() {
    final count = _outfitCount;
    final loading = count == null;
    final zero = count == 0;
    final navigable = !zero;

    return GestureDetector(
      // opaque so the whole 48px row is tappable — the Container has a
      // `decoration`, not a `color`, so it doesn't absorb hits itself.
      behavior: HitTestBehavior.opaque,
      onTap: navigable ? _openUsedInOutfits : null,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.checkroom_outlined,
              size: 24,
              color: AppColors.icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                zero ? _l10n.notUsedInOutfitsYet : _l10n.usedInOutfits,
                style: AppTextStyle.regular14.copyWith(
                  color: zero ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (navigable) ...[
              Text(
                '$count',
                style: AppTextStyle.bold14.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Image.asset(
                'assets/images/page_arrow_right.png',
                width: AppDimens.iconSmallSize,
                height: AppDimens.iconSmallSize,
              ),
            ],
          ],
        ),
      ),
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

  Widget _colorPicker() {
    final selected = _selectedColor;
    return TappableFieldDecorator(
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
                setState(() => _selectedColor = null);
                _checkModified();
                Navigator.pop(context);
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
      // opaque so the full 44px swatch is tappable — an unselected swatch's
      // Container has a `decoration` and no child, so it absorbs nothing on
      // its own.
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedColor = c);
        _checkModified();
        Navigator.pop(context);
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

  Widget _fitSlider() {
    final values = GarmentFit.values;
    // The slider always shows a concrete position (unlike the old picker,
    // which could sit at an explicit "nothing selected" state) — defaults
    // to Regular until the user actually drags it, at which point
    // _selectedFit becomes non-null and the change is tracked normally.
    final displayed = _selectedFit ?? GarmentFit.regular;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrong, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              activeTrackColor: AppColors.accentTint,
              inactiveTrackColor: AppColors.borderSubtle,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: displayed.index.toDouble(),
              min: 0,
              max: (values.length - 1).toDouble(),
              divisions: values.length - 1,
              onChanged: (v) {
                final fit = values[v.round()];
                setState(() => _selectedFit = fit);
                _checkModified();
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                displayed.localizedLabel(context),
                textAlign: TextAlign.center,
                style: AppTextStyle.regular16.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseDateField() {
    return TappableFieldDecorator(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _purchaseDate ?? now,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) {
          setState(() => _purchaseDate = picked);
          _checkModified();
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
              // Canonical GarmentImage instead of a hand-rolled
              // Image.network/Image.file — its RefreshableNetworkImage
              // downloads to a complete file before decoding, unlike a bare
              // Image.network streaming bytes straight into the decoder as
              // they arrive, which on an imperfect connection can decode a
              // truncated/torn frame instead of erroring cleanly (this is
              // what was actually producing the "torn" garment photos —
              // see git history, not a backend or crop-math bug after all).
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

  Future<void> _saveGarment() async {
    // Synchronous re-entrancy guard — the bottom button only hides ~200ms
    // after _uploading flips (BottomActionButton's AnimatedSwitcher), so a
    // double-tap could otherwise create two garment records / run two
    // uploads. See CLAUDE.md "Guarding costly / mutating actions against
    // double-invocation".
    if (_uploading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _uploading = true);

    try {
      final wasAdd = _isAddMode;
      // Adding uploads a fresh photo + creates the record; editing an
      // existing garment only ever updates its text fields — there is no
      // UI path to replace an existing garment's photo (see
      // _uploadNewGarment's doc comment).
      final result = _isAddMode
          ? await _uploadNewGarment()
          : await _updateGarmentFields();

      if (!mounted) return;
      await _adoptSaved(result, wasAdd: wasAdd);
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

  /// Save keeps the user on this page: the persisted garment is folded into
  /// local state (Add Mode flips to Edit Mode), the closet provider is
  /// updated here rather than via a pop result, and a confirmation shows.
  Future<void> _adoptSaved(Garment g, {required bool wasAdd}) async {
    // A new/edited photo lands at the *same* garmentImageCacheKey (stable,
    // keyed by id) as whatever was cached before — GarmentImage's disk
    // cache would otherwise keep serving the old bytes indefinitely since
    // nothing about the cache key itself changed. Read _isImageChanged
    // before the setState below resets it.
    final imageChanged = _isImageChanged && g.id != null;
    if (imageChanged) {
      ImageCacheBust.bump(garmentImageCacheKey(g.id!));
    }
    // Precache the freshly-uploaded photo under the exact cache key
    // GarmentImage will request — other surfaces showing this garment (the
    // Closet grid card, compatibility rows, ...) read the network URL from
    // the provider update below the moment it lands, so this is what keeps
    // *their* first paint from flashing a placeholder. This page's own
    // preview deliberately never makes that switch at all — see
    // _imagePathOrUrl below.
    final url = g.imageUrl;
    if (imageChanged && url != null && url.isNotEmpty) {
      final baseKey = garmentImageCacheKey(g.id!);
      final cacheKey = '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
      try {
        await precacheImage(
          CachedNetworkImageProvider(url, cacheKey: cacheKey),
          context,
        );
      } catch (e) {
        // Not fatal — GarmentImage falls back to its own placeholder/error
        // state same as any other failed load.
        debugLog('_adoptSaved: failed to precache garment photo: $e');
      }
      if (!mounted) return;
    }
    setState(() {
      _editingGarment = g;
      _id = g.id;
      _name = g.name;
      // Deliberately NOT _imagePathOrUrl = g.imageUrl — this page keeps
      // showing the local file (already decoded, already on screen) for
      // the rest of its own lifetime rather than switching to the network
      // copy of the same photo, which would otherwise flash a placeholder
      // as GarmentImage remounts onto a different widget branch. Other
      // screens pick up the real network URL from the provider update
      // below the moment they next build; only a fresh instance of *this*
      // page (a new visit from Closet) ever reads the network URL, via
      // _editingGarment in initState.
      _isImageChanged = false;
      _uploading = false;
      if (wasAdd) _outfitCount = 0;

      // Re-snapshot the change-detection baseline *before* touching the
      // controllers — assigning their text fires _checkModified, which must
      // see the new baseline so the form reads "not modified".
      _category = g.category;
      _purchaseDate = g.purchaseDate;
      _selectedColor = _tryParseGarmentColor(g.color);
      _selectedFit = GarmentFitX.fromApiValue(g.fit);
      _initialName = g.name;
      _initialCategory = g.category;
      _initialSub = g.subCategory;
      _initialBrand = g.brand ?? '';
      _initialPrice = g.price?.toString() ?? '';
      _initialColor = _selectedColor;
      _initialFit = _selectedFit;
      _initialDate = g.purchaseDate;
      _isModified = false;

      _nameCtrl.text = g.name;
      _subCategory.text = g.subCategory;
      _brandCtrl.text = g.brand ?? '';
      _priceCtrl.text = g.price?.toString() ?? '';
    });

    final notifier = ref.read(garmentsProvider.notifier);
    if (wasAdd) {
      notifier.addGarment(g);
    } else {
      notifier.updateGarment(g);
    }

    showFeedbackOverlay(
      context,
      message: wasAdd ? _l10n.clothingAdded : _l10n.changesSaved,
    );
  }

  /// Uploads the picked photo and creates a new garment record. Only ever
  /// called in add mode (see _saveGarment) — the backend has no "update
  /// image" endpoint, and there is no UI path to replace an existing
  /// garment's photo, so editing never reaches this method.
  Future<Garment> _uploadNewGarment() async {
    final initDate = await GarmentService().initUpload();
    await GarmentService().uploadImage(initDate.uploadUrl, _imagePathOrUrl!);
    final temp = Garment(
      uploadUrl: initDate.uploadUrl,
      objectName: initDate.objectName,
      category: _category,
      subCategory: _subCategory.text.trim(),
      name: _nameCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      color: _selectedColor?.label,
      fit: _selectedFit?.apiValue,
      price: double.tryParse(_priceCtrl.text.trim()),
      purchaseDate: _purchaseDate,
    );
    // Fold the one metadata field the form can edit (fit) back in. Never
    // send a bare `null` here: `/complete` requires `metadata` and 500s
    // reading `metadata.thickness` on a null value — `_metaData` is
    // normally seeded (fresh analysis, or an existing garment's own saved
    // metadata; see initState), but this is the last line of defense in
    // case both are somehow unavailable.
    final metadata = <String, dynamic>{
      ...?_metaData,
      if (_selectedFit != null) 'fit': _selectedFit!.apiValue,
    };
    return GarmentService().completeUpload(temp, metadata);
  }

  /// Updates just the text fields of an existing garment (image unchanged).
  Future<Garment> _updateGarmentFields() async {
    final updated = _editingGarment!.copyWith(
      name: _nameCtrl.text.trim(),
      category: _category,
      subCategory: _subCategory.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      color: _selectedColor?.label,
      fit: _selectedFit?.apiValue,
      clearFit: _selectedFit == null,
      price: double.tryParse(_priceCtrl.text.trim()),
      purchaseDate: _purchaseDate,
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

/// The "Uwearis AI" closet-analysis card — shown on Garment Details once the
/// garment is saved (edit mode only; see [_closetAnalysis]'s doc comment).
/// Starts as a one-line prompt + "Analyze with AI" button; once the user
/// runs it (or a persisted result is restored on open), shows a 1–10
/// versatility level, up to 3 outfit ideas, and up to 3 similar-in-closet
/// garments (see garments-api.md §8), plus a header refresh action to
/// re-run it. [onAnalyze] triggers the first run and a retry after
/// [errorMessage]; [onRefresh] re-runs it once [analysis] already exists,
/// keeping the old result on screen (and [isRefreshing] true) for the
/// duration. [onGarmentTap] opens the same [GarmentDetailDialog] Outfit
/// Details' own garment list uses, for a garment tapped inside an outfit
/// idea or the Similar in Your Closet row.
class _UwearisAiAnalysisCard extends StatelessWidget {
  final ClosetAnalysis? analysis;
  final bool isAnalyzing;
  final bool isRefreshing;
  final String? errorMessage;
  final VoidCallback onAnalyze;
  final VoidCallback onRefresh;
  final void Function(int garmentId) onGarmentTap;

  const _UwearisAiAnalysisCard({
    required this.analysis,
    required this.isAnalyzing,
    required this.isRefreshing,
    required this.errorMessage,
    required this.onAnalyze,
    required this.onRefresh,
    required this.onGarmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final Widget body;
    if (isAnalyzing) {
      body = _buildLoading(l10n);
    } else if (errorMessage != null) {
      body = _buildError(l10n, errorMessage!);
    } else if (analysis == null) {
      body = _buildPrompt(l10n);
    } else {
      body = _buildResult(context, l10n, analysis!);
    }

    return UwearisInsightCard(
      trailing: analysis == null ? null : _buildRefreshAction(),
      child: body,
    );
  }

  Widget _buildRefreshAction() {
    if (isRefreshing) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    return AccentIconButton(icon: Icons.refresh, onPressed: onRefresh);
  }

  Widget _buildLoading(AppLocalizations l10n) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            l10n.analyzingEllipsis,
            style: AppTextStyle.insightCardBody,
          ),
        ),
      ],
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVersatilitySection(context, l10n, analysis.versatility),
        // outfit_ideas / similar_garments come back empty rather than
        // padded with placeholders when the closet can't support them (see
        // garments-api.md §8) — each section is simply omitted rather than
        // showing empty space or a placeholder grid.
        if (ideas.isNotEmpty) ...[
          const SizedBox(height: 20),
          FieldLabel(l10n.outfitIdeasHeading.toUpperCase()),
          const SizedBox(height: 10),
          for (var i = 0; i < ideas.length; i++) ...[
            if (i > 0) const AppDivider(),
            _buildGarmentThumbRow(
              ideas[i].garments,
              onGarmentTap: onGarmentTap,
            ),
          ],
        ],
        if (similar.isNotEmpty) ...[
          const SizedBox(height: 20),
          FieldLabel(l10n.similarInClosetHeading.toUpperCase()),
          const SizedBox(height: 10),
          _buildGarmentThumbRow(similar, onGarmentTap: onGarmentTap),
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
        Text(l10n.versatilityDescription, style: AppTextStyle.insightCardBody),
        const SizedBox(height: 10),
        Text(
          l10n.versatilityLevelValue(versatility.level),
          style: AppTextStyle.bold18,
        ),
        const SizedBox(height: 8),
        _VersatilityLevelBar(level: versatility.level),
        const SizedBox(height: 10),
        Text(
          versatility.label.localizedLabel(context),
          style: AppTextStyle.bold14.copyWith(color: AppColors.accent),
        ),
      ],
    );
  }

  Widget _buildGarmentThumbRow(
    List<ClosetAnalysisGarment> garments, {
    void Function(int garmentId)? onGarmentTap,
  }) {
    return SizedBox(
      height: _AiGarmentThumb.size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: garments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = garments[i];
          return _AiGarmentThumb(
            garment: g,
            onTap: onGarmentTap == null
                ? null
                : () => onGarmentTap(g.garmentId),
          );
        },
      ),
    );
  }
}

/// Simple 10-segment fill bar for [ClosetAnalysisVersatility.level] (1–10) —
/// the "quickly readable at a glance" treatment the card wants without a
/// score-dashboard-sized ring or chart.
class _VersatilityLevelBar extends StatelessWidget {
  final int level;

  const _VersatilityLevelBar({required this.level});

  static const int _segments = 10;

  @override
  Widget build(BuildContext context) {
    final filled = level.clamp(0, _segments);
    return Row(
      children: [
        for (var i = 0; i < _segments; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < filled ? AppColors.accent : AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact garment thumbnail for the AI analysis card's outfit-idea and
/// similar-garments rows — same bordered-square shape as the "compatible
/// garments" thumbnails this card used to show (see git history), just
/// smaller. [ClosetAnalysisGarment.isTarget] gets a subtly accent-colored
/// border instead of a separate badge/label, so the analyzed garment reads
/// as "this one" within an outfit idea without adding visual complexity.
/// [onTap] opens the same [GarmentDetailDialog] Outfit Details' own garment
/// list uses; leave it null for a non-interactive thumbnail.
class _AiGarmentThumb extends StatelessWidget {
  final ClosetAnalysisGarment garment;
  final VoidCallback? onTap;

  const _AiGarmentThumb({required this.garment, this.onTap});

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final thumb = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: garment.isTarget ? AppColors.accent : AppColors.borderSubtle,
          width: garment.isTarget ? 1.5 : 1,
        ),
      ),
      child: GarmentImage(
        url: garment.imageUrl,
        garmentId: garment.garmentId,
        memCacheWidth: 128,
        memCacheHeight: 128,
        fit: BoxFit.cover,
      ),
    );
    if (onTap == null) return thumb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: thumb,
    );
  }
}
