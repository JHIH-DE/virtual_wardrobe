import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/services/error_handler.dart';
import '../core/services/garment_service.dart';
import '../core/services/profile_service.dart';
import '../data/token_storage.dart';
import '../data/garment_category.dart';
import 'image_edit_page.dart';

class AddGarmentPage extends StatefulWidget {
  final Garment? initialGarment;
  const AddGarmentPage({super.key, this.initialGarment});

  @override
  State<AddGarmentPage> createState() => _AddGarmentPageState();
}

class _AddGarmentPageState extends State<AddGarmentPage> {
  final _formKey = GlobalKey<FormState>();

  int? _id;
  GarmentCategory category = GarmentCategory.top;

  final _nameCtrl = TextEditingController();
  final _subCategory = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  GarmentColor? _selectedColor;
  DateTime? _purchaseDate;

  String? _imagePathOrUrl;
  String? _initialImagePathOrUrl;
  bool _isImageChanged = false;
  bool _isAnalyzing = false;

  bool uploading = false;
  String? errorMessage;
  String? _userGender;

  @override
  void initState() {
    super.initState();
    _getGender();
    final g = widget.initialGarment;
    _id = g?.id;
    _imagePathOrUrl = g?.imageUrl;
    _initialImagePathOrUrl = g?.imageUrl;
    category = g?.category ?? GarmentCategory.top;
    _subCategory.text = g?.subCategory ?? '';
    _nameCtrl.text = g?.name ?? '';
    _brandCtrl.text = g?.brand ?? '';
    _priceCtrl.text = g?.price?.toString() ?? '';
    _purchaseDate = g?.purchaseDate;
    _selectedColor = _tryParseGarmentColor(g?.color);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subCategory.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.initialGarment != null;

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Edit Garment' : 'Add Garment';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (uploading) const LinearProgressIndicator(),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              ),

            _imagePreview(),

            const SizedBox(height: 22),

            _sectionTitle('Basic'),

            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDecoration(label: 'Name'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter name';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<GarmentCategory>(
              value: category,
              decoration: _inputDecoration(label: 'Category'),
              items: GarmentCategory.values
                  .where((c) => c != GarmentCategory.dress || _userGender == 'Female')
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _subCategory,
              decoration: _inputDecoration(label: 'Product Type'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter product type';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            _colorPicker(),

            const SizedBox(height: 12),

            TextFormField(
              controller: _brandCtrl,
              decoration: _inputDecoration(label: 'Brand (optional)'),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _priceCtrl,
              decoration: _inputDecoration(label: 'Price (optional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: 12),

            _purchaseDateField(context),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: uploading ? null : _saveGarment,
              icon: const Icon(Icons.check),
              label: Text(_isEditMode ? 'Save changes' : 'Create Garment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------
  // Widgets
  // ----------------------------

  Widget _colorPicker() {
    final selected = _selectedColor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openColorPickerSheet,
      child: InputDecorator(
        decoration: _inputDecoration(label: 'Color'),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selected?.color ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == null ? AppColors.border : Colors.transparent,
                  width: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Text(
                selected?.label ?? 'Select a color',
                style: TextStyle(
                  color: selected == null ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 14.5,
                ),
              ),
            ),

            if (selected != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: () => setState(() => _selectedColor = null),
                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
      builder: (_) {
        return Container(
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
                      child: Text(
                        'Choose a color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedColor = null);
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

                        final borderColor = isSelected
                            ? AppColors.primary
                            : (c == GarmentColor.white ||
                            c == GarmentColor.beige ||
                            c == GarmentColor.yellow)
                            ? Colors.grey.shade400
                            : Colors.transparent;

                        final borderWidth = isSelected ? 2.5 : 1.2;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedColor = c);
                            Navigator.pop(context);
                          },
                          child: Tooltip(
                            message: c.label,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: borderWidth),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, size: 20, color: c.preferredCheckColor)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _purchaseDateField(BuildContext context) {
    final text = _purchaseDate == null
        ? 'Purchase date (optional)'
        : _formatDate(_purchaseDate!);

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
        if (picked != null) setState(() => _purchaseDate = picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration(label: 'Purchase date'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: _purchaseDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 14.5,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
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
          onTap: _openImageEdit,
          child: const AspectRatio(
            aspectRatio: 1.35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.textSecondary),
                SizedBox(height: 8),
                Text('Tap to add photo', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final isLocal = !img.startsWith('http');

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openImageEdit,
                child: AspectRatio(
                  aspectRatio: 1.35,
                  child: Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: isLocal
                        ? Image.file(File(img), fit: BoxFit.contain)
                        : Image.network(img, fit: BoxFit.contain),
                  ),
                ),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  SizedBox(height: 12),
                  Text(
                    'AI Analyzing...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openImageEdit() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditPage(initialPath: _imagePathOrUrl),
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      _imagePathOrUrl = result;
      _isImageChanged = (_imagePathOrUrl != _initialImagePathOrUrl);
    });

    try {
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        // --- 修改開始：開啟載入狀態 ---
        setState(() => _isAnalyzing = true);

        debugPrint('Analyzing garment image: $result');
        final analysisData = await GarmentService().analyzeInstantGarment(token, result);

        debugPrint('--- AI Analysis Data ---');
        debugPrint(analysisData.toString());

        setState(() {
          if (analysisData['name'] != null) {
            _nameCtrl.text = analysisData['name'].toString();
          }

          final String? catStr = analysisData['category']?.toString().toLowerCase();
          if (catStr != null) {
            for (var val in GarmentCategory.values) {
              if (val.name.toLowerCase() == catStr || val.label.toLowerCase() == catStr) {
                category = val;
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
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('AI Analysis failed: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveGarment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final isAdd = widget.initialGarment?.id == null;

    setState(() {
      uploading = true;
      errorMessage = null;
    });

    try {
      final token = await TokenStorage.getAccessToken();
      late Garment result;

      if (isAdd || _isImageChanged) {
        final raw = (_imagePathOrUrl ?? '').trim();
        final initDate = await GarmentService().initUpload(token!);
        await GarmentService().uploadImage(initDate.uploadUrl, raw);

        final tempGarment = Garment(
          uploadUrl: initDate.uploadUrl,
          objectName: initDate.objectName,
          category: category,
          subCategory: _subCategory.text.trim(),
          name: _nameCtrl.text.trim(),
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          color: _selectedColor?.label,
          price: _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text.trim()),
          purchaseDate: _purchaseDate,
        );

        if (_isImageChanged && !isAdd && _id != null) {
          await GarmentService().deleteGarment(token, _id!);
        }
        result = await GarmentService().completeUpload(token, tempGarment);
      } else {
        final original = widget.initialGarment!;
        Garment updated = original.copyWith(
          name: _nameCtrl.text.trim(),
          category: category,
          subCategory: _subCategory.text.trim(),
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          color: _selectedColor?.label,
          price: _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text.trim()),
          purchaseDate: _purchaseDate,
        );
        result = await GarmentService().updateGarment(token!, updated);
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  // ----------------------------
  // Helpers
  // ----------------------------

  Future<void> _getGender() async {
    try {
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        final profile = await ProfileService().getMyProfile(token);
        setState(() {
          _userGender = profile['gender'];
        });
      }
    } catch (e) {
      debugPrint('Failed to _getGender: $e');
    }
  }

  GarmentColor? _tryParseGarmentColor(String? colorText) {
    if (colorText == null) return null;
    final normalized = colorText.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final c in GarmentColor.values) {
      final cName = c.name.toLowerCase();
      final cLabel = c.label.toLowerCase();
      
      if (normalized.contains(cName) || cName.contains(normalized) ||
          normalized.contains(cLabel) || cLabel.contains(normalized)) {
        return c;
      }
    }
    return null;
  }

  String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}';
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _inputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }
}
