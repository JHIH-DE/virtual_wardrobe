import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'garment_category.dart';
import 'image_edit_page.dart';
import '../app/theme/app_colors.dart';

class AddGarmentPage extends StatefulWidget {
  /// If provided, page works as "Edit Item"
  final Garment? initialGarment;

  const AddGarmentPage({super.key, this.initialGarment});

  @override
  State<AddGarmentPage> createState() => _AddGarmentPageState();
}

class _AddGarmentPageState extends State<AddGarmentPage> {
  late GarmentCategory category;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _priceCtrl;

  GarmentSeason? _season;
  DateTime? _purchaseDate;

  /// local file path (demo mode) or network url
  String? _imagePathOrUrl;

  @override
  void initState() {
    super.initState();
    final g = widget.initialGarment;
    category = g?.category ?? GarmentCategory.top;

    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _brandCtrl = TextEditingController(text: g?.brand ?? '');
    _colorCtrl = TextEditingController(text: g?.color ?? '');
    _priceCtrl = TextEditingController(
      text: g?.price == null ? '' : g!.price!.toStringAsFixed(0),
    );

    _season = g?.season;
    _purchaseDate = g?.purchaseDate;
    _imagePathOrUrl = g?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _colorCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.initialGarment != null;

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Edit Item' : 'Add Item';

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
            _sectionTitle('Basic'),
            const SizedBox(height: 8),

            DropdownButtonFormField<GarmentCategory>(
              value: category,
              decoration: _inputDecoration(label: 'Category'),
              items: GarmentCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),

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

            TextFormField(
              controller: _brandCtrl,
              decoration: _inputDecoration(label: 'Brand (optional)'),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _colorCtrl,
              decoration: _inputDecoration(label: 'Color (optional)'),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<GarmentSeason>(
              value: _season,
              decoration: _inputDecoration(label: 'Season (optional)'),
              items: GarmentSeason.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _season = v),
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

            _sectionTitle('Image'),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _openImageEdit,
              icon: const Icon(Icons.edit),
              label: Text(_imagePathOrUrl == null ? 'Add image' : 'Edit image'),
              style: _outlineBtnStyle(),
            ),

            const SizedBox(height: 12),

            _imagePreview(),

            const SizedBox(height: 22),

            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditMode ? 'Save changes' : 'Create item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _purchaseDateField(BuildContext context) {
    final text = _purchaseDate == null
        ? 'Purchase date (optional)'
        : DateFormat('yyyy/MM/dd').format(_purchaseDate!);

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
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No image selected',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final isLocal = !img.startsWith('http');

    return Container(
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
        child: AspectRatio(
          aspectRatio: 1.35,
          child: isLocal
              ? Image.file(File(img), fit: BoxFit.cover)
              : Image.network(img, fit: BoxFit.cover),
        ),
      ),
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
    setState(() => _imagePathOrUrl = result);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameCtrl.text.trim();
    final brand = _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim();
    final color = _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim();

    final priceText = _priceCtrl.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);

    final imageUrl = (_imagePathOrUrl ?? '').trim();
    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image.')),
      );
      return;
    }

    final updated = Garment(
      id: widget.initialGarment?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      brand: brand,
      color: color,
      season: _season,
      price: price,
      purchaseDate: _purchaseDate,
      category: category,
      imageUrl: imageUrl,
    );

    Navigator.pop(context, updated);
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

  ButtonStyle _outlineBtnStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );
  }
}