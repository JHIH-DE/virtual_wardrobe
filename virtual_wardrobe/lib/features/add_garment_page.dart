import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garments_service.dart';
import '../core/utils/debug_log.dart';
import '../data/garment.dart';
import '../data/image_edit_result.dart';
import 'garment_looks_page.dart';
import 'image_editor_page.dart';
import 'widgets/app_dialog.dart';
import 'widgets/app_text_field.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/custom_dropdown.dart';
import 'widgets/page_app_bar.dart';

class AddGarmentPage extends ConsumerStatefulWidget {
  final Garment? initialGarment;
  final Map<String, dynamic>? initialAnalysisData;

  const AddGarmentPage({
    super.key,
    this.initialGarment,
    this.initialAnalysisData,
  });

  @override
  ConsumerState<AddGarmentPage> createState() => _AddGarmentPageState();
}

class _AddGarmentPageState extends ConsumerState<AddGarmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _subCategory = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _isImageChanged = false;
  bool _isAnalyzing = false;
  bool uploading = false;
  int? _id;
  String? errorMessage;
  String? _userGender;
  String? _imagePathOrUrl;
  GarmentColor? _selectedColor;
  GarmentCategory _category = GarmentCategory.top;
  DateTime? _purchaseDate;
  Garment? _editingGarment;
  Map<String, dynamic>? _metaData;

  bool _isFavorite = false;
  bool _isFavoriteLoading = false;

  bool _isModified = false;
  late String _initialName;
  late GarmentCategory _initialCategory;
  late String _initialSub;
  late String _initialBrand;
  late String _initialPrice;
  GarmentColor? _initialColor;
  DateTime? _initialDate;

  @override
  void initState() {
    super.initState();
    _editingGarment = widget.initialGarment;
    _id = _editingGarment?.id;
    _imagePathOrUrl = _editingGarment?.imageUrl;
    _isFavorite = _editingGarment?.isFavorite ?? false;

    // 初始化初始值，用於後續比較
    _initialName = _editingGarment?.name ?? '';
    _initialCategory = _editingGarment?.category ?? GarmentCategory.top;
    _initialSub = _editingGarment?.subCategory ?? '';
    _initialBrand = _editingGarment?.brand ?? '';
    _initialPrice = _editingGarment?.price?.toString() ?? '';
    _initialColor = _tryParseGarmentColor(_editingGarment?.color);
    _initialDate = _editingGarment?.purchaseDate;

    if (_editingGarment != null) {
      _category = _editingGarment!.category;
      _subCategory.text = _editingGarment!.subCategory;
      _nameCtrl.text = _editingGarment!.name;
      _brandCtrl.text = _editingGarment!.brand ?? '';
      _priceCtrl.text = _editingGarment!.price?.toString() ?? '';
      _purchaseDate = _editingGarment!.purchaseDate;
      _selectedColor ??= _initialColor;
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

  // 修改變數名稱：當沒有 ID 時，代表是新增模式 (Add Mode)
  bool get _isAddMode => _id == null;

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Delete Garment',
        body: 'Are you sure you want to delete this garment?',
        primaryLabel: 'Delete',
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );

    if (confirm == true && _id != null) {
      try {
        await GarmentService().deleteGarment(_id!);
        if (!mounted) return;
        Navigator.pop(context, 'deleted');
      } catch (e) {
        if (e is AuthExpiredException) {
          await AuthExpiredHandler.handle(context);
          return;
        }
        setState(() => errorMessage = 'Delete failed: $e');
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isModified) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'You have unsaved changes',
        body: 'If you leave this page, your changes will be lost.',
        primaryLabel: 'Save',
        onPrimary: () => Navigator.pop(ctx, 'save'),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx, 'cancel'),
        tertiaryLabel: "Don't Save",
        onTertiary: () => Navigator.pop(ctx, 'discard'),
      ),
    );

    if (result == 'save') {
      await _saveGarment();
      return false;
    }
    return result == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final title = _isAddMode ? 'Add Clothing' : 'Clothing Details';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.defaultBackground,
        extendBody: true,
        appBar: PageAppBar(
          title: title,
          onBack: () async {
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) Navigator.pop(context);
          },
          actions: [
            if (!_isAddMode)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/images/delete.png',
                    height: AppDimens.iconMediumSize,
                  ),
                ),
                onPressed: _handleDelete,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              const SizedBox(height: 20),
              if (uploading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(),
                ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _imagePreview(),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                decoration: const BoxDecoration(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isAddMode) _buildActionButtons(),
                    const SizedBox(height: 8),
                    _sectionTitle('Clothing Name'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _nameCtrl,
                      hint: 'Name the clothing',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter name'
                          : null,
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle('Clothing Category'),
                    const SizedBox(height: 8),
                    CustomDropdown<GarmentCategory>(
                      value: _category,
                      items: GarmentCategory.values
                          .where(
                            (c) =>
                                c != GarmentCategory.dress ||
                                _userGender == 'Female',
                          )
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.label,
                                style: AppTextStyle.regular14,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _category = v);
                          _checkModified();
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle('Product Type'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _subCategory,
                      hint: 'e.g. Top',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter product type'
                          : null,
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle('Color'),
                    const SizedBox(height: 8),
                    _colorPicker(),

                    const SizedBox(height: 20),
                    _sectionTitle('Brand (optional)'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _brandCtrl,
                      hint: 'What is the brand of this clothing?',
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle('Price (optional)'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _priceCtrl,
                      hint: 'How much is this clothing?',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle('Purchase date'),
                    const SizedBox(height: 8),
                    _purchaseDateField(context),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 固定在底部的儲存按鈕
        bottomNavigationBar: BottomActionButton(
          label: _isAddMode ? 'Add to Closet' : 'Save',
          onPressed: _isModified ? _saveGarment : null,
          isLoading: uploading,
        ),
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
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('AI Analysis failed: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  // ----------------------------
  // Widgets
  // ----------------------------

  Widget _buildActionButtons() {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
              iconColor: _isFavorite ? Colors.red : AppColors.textPrimary,
              label: 'Favorite',
              onTap: _isFavoriteLoading ? null : _toggleFavorite,
            ),
          ),
          Expanded(
            child: _buildActionButton(
              icon: Icons.checkroom_outlined,
              label: 'Used in Looks',
              onTap: () {
                final gid = _editingGarment?.garmentId ?? _editingGarment?.id;
                debugLog(
                  'Used in Looks tapped: garmentId=${_editingGarment?.garmentId} id=${_editingGarment?.id} → passing $gid',
                );
                if (gid == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GarmentLooksPage(garmentId: gid),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: iconColor ?? AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_id == null) return;
    final next = !_isFavorite;
    setState(() {
      _isFavorite = next;
      _isFavoriteLoading = true;
    });
    try {
      await GarmentService().setFavorite(_id!, isFavorite: next);
      ref
          .read(garmentsProvider.notifier)
          .updateFavorite(_id!, isFavorite: next);
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      if (mounted) setState(() => _isFavorite = !next);
    } finally {
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  Widget _colorPicker() {
    final selected = _selectedColor;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openColorPickerSheet,
      child: InputDecorator(
        decoration: appInputDecoration(hint: ''),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selected?.color ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == null
                      ? AppColors.border
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected?.label ?? 'Select a color',
                style: AppTextStyle.regular14.copyWith(
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
      ),
    );
  }

  void _openColorPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text('Choose a color', style: AppTextStyle.bold16),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedColor = null);
                      _checkModified();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: GarmentColor.values.map((c) {
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
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.black12,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 20,
                                  color: c.preferredCheckColor,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purchaseDateField(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
      child: InputDecorator(
        decoration: appInputDecoration(hint: ''),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _purchaseDate == null
                    ? 'Select date'
                    : '${_purchaseDate!.year}/${_purchaseDate!.month}/${_purchaseDate!.day}',
                style: TextStyle(
                  color: _purchaseDate == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreview() {
    final img = _imagePathOrUrl;
    if (img == null || img.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: InkWell(
          onTap: _pickNewImage,
          child: const AspectRatio(
            aspectRatio: 1.35,
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: AppColors.textSecondary,
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.1,
              child: img.startsWith('http')
                  ? Image.network(img, fit: BoxFit.contain)
                  : Image.file(File(img), fit: BoxFit.contain),
            ),
          ),
        ),
        // Edit Image 按鈕
        Positioned(
          bottom: 12,
          right: 12,
          child: GestureDetector(
            onTap: _editCurrentImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Row(
                children: [
                  const Text('Edit image', style: AppTextStyle.bold16),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/edit.png',
                    height: AppDimens.iconSmallSize,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isAnalyzing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
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
        builder: (_) => ImageEditorPage(initialPath: xfile.path),
      ),
    );
    _handleImageEditResult(result);
  }

  Future<void> _editCurrentImage() async {
    if (_imagePathOrUrl == null) return;

    if (!mounted) return;
    final result = await Navigator.push<ImageEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImageEditorPage(initialPath: _imagePathOrUrl, showAnalysis: false),
      ),
    );
    _handleImageEditResult(result);
  }

  Future<void> _saveGarment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      uploading = true;
      errorMessage = null;
    });

    try {
      Garment result;
      // 當新增模式或圖片變更時執行上傳
      if (_isAddMode || _isImageChanged) {
        final initDate = await GarmentService().initUpload();
        await GarmentService().uploadImage(
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
          price: double.tryParse(_priceCtrl.text.trim()),
          purchaseDate: _purchaseDate,
        );
        // 如果是在編輯模式下更換圖片，先刪除舊紀錄
        if (!_isAddMode) await GarmentService().deleteGarment(_id!);
        result = await GarmentService().completeUpload(temp, _metaData);
      } else {
        // 單純更新文字資料
        final updated = _editingGarment!.copyWith(
          name: _nameCtrl.text.trim(),
          category: _category,
          subCategory: _subCategory.text.trim(),
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          color: _selectedColor?.label,
          price: double.tryParse(_priceCtrl.text.trim()),
          purchaseDate: _purchaseDate,
        );
        result = await GarmentService().updateGarment(updated);
      }

      if (!mounted) return;
      _showSuccessOverlay();

      // 延遲一段時間讓使用者看到成功訊息，然後關閉彈窗並返回上一頁
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      Navigator.of(context).pop(); // 關閉成功彈窗
      Navigator.of(context).pop(result); // 關閉 AddGarmentPage 並回傳結果
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          uploading = false;
        });
      }
    }
  }

  void _showSuccessOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Changes Saved',
                style: AppTextStyle.bold16.copyWith(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _sectionTitle(String text) {
    return Text(text, style: AppTextStyle.bold14);
  }
}
