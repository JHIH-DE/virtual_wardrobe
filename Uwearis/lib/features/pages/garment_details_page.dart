import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/signed_url.dart';
import '../../data/garment.dart';
import '../../data/image_edit_result.dart';
import '../../data/outfit.dart';
import '../../data/versatility.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/buttons/close_action_button.dart';
import '../widgets/common/buttons/pill_button.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/cards/score_ring.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/fields/labeled_field.dart';
import '../widgets/common/fields/picker_field.dart';
import '../widgets/common/fields/tappable_field_decorator.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/inline_error_text.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/garment/compatibility_row.dart';
import '../widgets/garment/garment_image.dart';
import 'garment_outfits_page.dart';
import 'image_editor_page.dart';

enum _GarmentMenuAction { rename, share, delete }

class GarmentDetailsPage extends ConsumerStatefulWidget {
  final Garment? initialGarment;
  final Map<String, dynamic>? initialAnalysisData;
  final Versatility? initialVersatility;

  const GarmentDetailsPage({
    super.key,
    this.initialGarment,
    this.initialAnalysisData,
    this.initialVersatility,
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
  String? _errorMessage;
  String? _imagePathOrUrl;
  GarmentColor? _selectedColor;
  GarmentFit? _selectedFit;
  GarmentCategory _category = GarmentCategory.top;
  DateTime? _purchaseDate;
  Garment? _editingGarment;
  Map<String, dynamic>? _metaData;
  Versatility? _versatility;
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
      _versatility = widget.initialVersatility;
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
      _loadOutfitCount();
    }
  }

  int? get _garmentIdForOutfits =>
      _editingGarment?.garmentId ?? _editingGarment?.id;

  Future<void> _loadOutfitCount() async {
    final gid = _garmentIdForOutfits;
    if (gid == null) return;
    try {
      final outfits = await OutfitService().getOutfitsByGarments([gid]);
      // `by-garments` also returns daily/trip-generated outfits, which
      // GarmentOutfitsPage excludes — keep this count in sync with what
      // that page actually shows.
      final count = outfits
          .where((o) => o.groupType == OutfitGroupType.general)
          .length;
      if (mounted) setState(() => _outfitCount = count);
    } catch (e) {
      // Tile just stays in its loading state; not worth surfacing an error
      // for a secondary count that the user can still reach via the tap —
      // but still log it, so a silent failure here doesn't go unnoticed.
      debugLog('Failed to load outfit count: $e');
    }
  }

  /// Re-fetches the garment if its signed image URL has expired, so the
  /// preview (and any edit flow launched from it) doesn't show a stale link.
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

  // Mirrors OutfitDetailsPage._shareOutfit — sharing isn't implemented on
  // either page yet, just the placeholder entry point.
  void _shareGarment() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.shareComingSoon)));
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
        _nameCtrl.text = updated.name;
        _initialName = updated.name;
      });
      ref.read(garmentsProvider.notifier).updateGarment(updated);
    } on AuthExpiredException {
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        setState(() => _errorMessage = _l10n.deleteFailedPrefix(e.toString()));
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isModified) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.unsavedChangesTitle,
        body: _l10n.unsavedChangesBody,
        primaryLabel: _l10n.save,
        onPrimary: () => Navigator.pop(ctx, 'save'),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, 'cancel'),
        tertiaryLabel: _l10n.dontSave,
        onTertiary: () => Navigator.pop(ctx, 'discard'),
      ),
    );

    if (result == 'save') {
      await _saveGarment();
      return false;
    }
    return result == 'discard';
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      // Blank — the name shows as its own block below the app bar instead
      // (see [_buildForm]), so it isn't in the toolbar at all.
      title: '',
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
      canPop: false,
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
        body: _buildForm(),
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
            child: Text(_title, style: AppTextStyle.bold20),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: AppDivider(topSpacing: 12, bottomSpacing: 16),
          ),
          if (_uploading) _buildUploadProgress(),
          if (_errorMessage != null)
            InlineErrorText(
              message: _errorMessage!,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _imagePreview(),
          ),
          if (_isAddMode) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _OutfitPotentialCard(
                versatility: _versatility,
                subCategory: _subCategory.text.trim(),
                allGarments: ref.watch(garmentsProvider).value ?? const [],
                onRowTap: _showCompatibleGarments,
              ),
            ),
          ],
          const SizedBox(height: AppDimens.sectionSpacing),
          _buildDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: LinearProgressIndicator(),
    );
  }

  void _showCompatibleGarments(VersatilityCategory row) {
    final category = row.category;
    final all = ref.read(garmentsProvider).value ?? const [];
    final garments = _resolveCompatibleGarments(row, all, limit: 9);

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                category.pluralLabel(ctx),
                textAlign: TextAlign.center,
                style: AppTextStyle.bold20,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final g in garments)
                    Container(
                      width: 84,
                      height: 84,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.borderStrong),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: GarmentImage(
                        url: g.imageUrl,
                        garmentId: g.id,
                        memCacheWidth: 168,
                        memCacheHeight: 168,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              CloseActionButton(onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
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
          // Editing an existing garment renames via the App Bar's ⋮ ▸
          // Rename dialog instead (see _showRenameDialog) — this inline
          // field is only needed in Add Mode, before a rename option even
          // exists (no garment id yet to rename).
          if (_isAddMode) ...[_buildNameField(), const SizedBox(height: 20)],
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

  Widget _buildNameField() {
    return LabeledField(
      label: _l10n.clothingNameLabel,
      child: AppTextField(
        controller: _nameCtrl,
        hint: _l10n.nameTheClothingHint,
        validator: (v) => (v == null || v.trim().isEmpty)
            ? _l10n.pleaseEnterNameError
            : null,
      ),
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
        _versatility = result.versatility;
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

  Widget _buildUsedInOutfitsTile() {
    final count = _outfitCount;
    final loading = count == null;
    final zero = count == 0;
    final navigable = !zero;

    return GestureDetector(
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
    if (img == null || img.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          border: Border.all(
            color: AppColors.borderSubtle,
            style: BorderStyle.solid,
          ),
        ),
        child: InkWell(
          onTap: _pickNewImage,
          child: const AspectRatio(
            aspectRatio: 1.35,
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: AppColors.icon,
            ),
          ),
        ),
      );
    }

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
              child: img.startsWith('http')
                  ? Image.network(
                      img,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image, color: AppColors.icon),
                      ),
                    )
                  : Image.file(File(img), fit: BoxFit.contain),
            ),
          ),
        ),
        // Edit Image button
        Positioned(
          bottom: 12,
          right: 12,
          child: PillButton.floating(
            label: _l10n.editImage,
            icon: Image.asset(
              'assets/images/edit.png',
              height: AppDimens.iconSmallSize,
            ),
            onPressed: _editCurrentImage,
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

  void _handleImageEditResult(ImageEditResult? result) {
    if (result != null) {
      setState(() {
        _imagePathOrUrl = result.imagePath;
        _isImageChanged = true;
        if (result.analysisData != null) {
          _applyAnalysisData(result.analysisData!);
          _versatility = result.versatility;
        }
      });
      _checkModified();
    }
  }

  Future<void> _pickNewImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    if (!mounted) return;
    final result = await Navigator.push<ImageEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(initialPath: xfile.path, title: _title),
      ),
    );
    _handleImageEditResult(result);
  }

  Future<void> _editCurrentImage() async {
    if (_imagePathOrUrl == null) return;

    await _ensureFreshImage();
    if (!mounted) return;
    final result = await Navigator.push<ImageEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          initialPath: _imagePathOrUrl,
          showAnalysis: false,
          title: _title,
        ),
      ),
    );
    _handleImageEditResult(result);
  }

  Future<void> _saveGarment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _uploading = true;
      _errorMessage = null;
    });

    try {
      // Upload when adding or when the image changed; otherwise just update text fields
      final result = (_isAddMode || _isImageChanged)
          ? await _uploadNewGarment()
          : await _updateGarmentFields();

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on AuthExpiredException {
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _uploading = false;
        });
      }
    }
  }

  /// Uploads the (new or edited) image, then creates the garment record.
  /// In edit mode this replaces the previous record entirely, since the
  /// backend has no "update image" endpoint.
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
    // When replacing the image in edit mode, delete the old record first
    if (!_isAddMode) await GarmentService().deleteGarment(_id!);
    return GarmentService().completeUpload(temp, _metaData);
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

/// Resolves a versatility breakdown row's `compatibleGarmentIds` against the
/// user's already-loaded closet, for both a row's preview thumbnails and the
/// full "see all" dialog grid.
List<Garment> _resolveCompatibleGarments(
  VersatilityCategory row,
  List<Garment> all, {
  int? limit,
}) {
  final matched = <Garment>[
    for (final id in row.compatibleGarmentIds)
      for (final g in all)
        if (g.id == id) g,
  ];
  return limit == null ? matched : matched.take(limit).toList();
}

/// The "outfit potential" insight card shown in add-garment mode — a
/// versatility score ring plus a per-category compatibility breakdown.
/// Renders nothing until [versatility] carries a score. [onRowTap] gets the
/// breakdown row for the category whose row was tapped.
class _OutfitPotentialCard extends StatelessWidget {
  final Versatility? versatility;
  final String subCategory;
  final List<Garment> allGarments;
  final void Function(VersatilityCategory row) onRowTap;

  const _OutfitPotentialCard({
    required this.versatility,
    required this.subCategory,
    required this.allGarments,
    required this.onRowTap,
  });

  String _scoreTierLabel(AppLocalizations l10n, int score) {
    if (score >= 90) return l10n.scoreTierExcellent;
    if (score >= 75) return l10n.scoreTierHighlyVersatile;
    if (score >= 55) return l10n.scoreTierGoodMatch;
    if (score >= 35) return l10n.scoreTierLimitedMatch;
    return l10n.scoreTierHardToStyle;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final score = versatility?.score;
    final breakdown =
        versatility?.breakdown
            .where(
              (row) =>
                  row.compatibleCount > 0 &&
                  row.category != GarmentCategory.accessory &&
                  row.category != GarmentCategory.socks,
            )
            .toList() ??
        const [];

    if (score == null) return const SizedBox.shrink();

    final totalItems = breakdown.fold<int>(
      0,
      (sum, row) => sum + row.compatibleCount,
    );

    return UwearisInsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  ScoreRing(score: score, size: 70),
                  const SizedBox(height: 6),
                  Text(
                    _scoreTierLabel(l10n, score),
                    style: AppTextStyle.bold12.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    subCategory.isEmpty
                        ? l10n.garmentPairsWellWithGeneric(totalItems)
                        : l10n.garmentPairsWellWith(subCategory, totalItems),
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (var i = 0; i < breakdown.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              CompatibilityRow(
                label: breakdown[i].category.pluralLabel(context),
                count: breakdown[i].compatibleCount,
                previewGarments: _resolveCompatibleGarments(
                  breakdown[i],
                  allGarments,
                  limit: 3,
                ),
                onTap: () => onRowTap(breakdown[i]),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
