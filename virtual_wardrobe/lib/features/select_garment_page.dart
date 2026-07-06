import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../data/garment.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/garment_card.dart';
import 'widgets/page_app_bar.dart';

class SelectGarmentResult {
  final Garment? garment;
  const SelectGarmentResult(this.garment);
}

class SelectGarmentPage extends StatefulWidget {
  final String title;
  final GarmentCategory category;
  final List<Garment> garments;
  final Garment? selected;

  const SelectGarmentPage({
    super.key,
    required this.title,
    required this.category,
    required this.garments,
    this.selected,
  });

  @override
  State<SelectGarmentPage> createState() => _SelectGarmentPageState();
}

class _SelectGarmentPageState extends State<SelectGarmentPage> {
  Set<String> _selectedColors = {'All'};
  Set<String> _selectedTypes = {'All'};
  Garment? _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.selected;
  }

  List<Garment> get _byCategory =>
      widget.garments.where((g) => g.category == widget.category).toList();

  List<String> get _availableColors {
    final colors = _byCategory
        .map((g) => g.color)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...colors];
  }

  List<String> get _availableTypes {
    final types = _byCategory
        .map((g) => g.subCategory)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...types];
  }

  bool get _isFiltered =>
      !_selectedColors.contains('All') || !_selectedTypes.contains('All');

  List<Garment> get _filtered {
    return _byCategory.where((g) {
      final okColor = _selectedColors.contains('All') ||
          (g.color != null &&
              _selectedColors.any(
                  (c) => c.toLowerCase() == g.color!.toLowerCase()));
      final okType = _selectedTypes.contains('All') ||
          _selectedTypes
              .any((t) => t.toLowerCase() == g.subCategory.toLowerCase());
      return okColor && okType;
    }).toList();
  }

  void _toggleChip(
      Set<String> set, String value, void Function(Set<String>) update) {
    setState(() {
      if (value == 'All') {
        update({'All'});
      } else {
        final next = Set<String>.from(set)..remove('All');
        if (next.contains(value)) {
          next.remove(value);
          if (next.isEmpty) next.add('All');
        } else {
          next.add(value);
        }
        update(next);
      }
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void toggle(Set<String> set, String value,
              void Function(Set<String>) update) {
            setSheetState(() {});
            _toggleChip(set, value, update);
          }

          Widget chipRow(List<String> options, Set<String> selected,
              void Function(Set<String>) update) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((s) {
                final isSel = selected.contains(s);
                return GestureDetector(
                  onTap: () => toggle(selected, s, update),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      s,
                      style: AppTextStyle.semibold14.copyWith(
                        color: isSel ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Color', style: AppTextStyle.bold16),
                const SizedBox(height: 10),
                chipRow(_availableColors, _selectedColors,
                    (v) => _selectedColors = v),
                const SizedBox(height: 20),
                Text('Product Type', style: AppTextStyle.bold16),
                const SizedBox(height: 10),
                chipRow(_availableTypes, _selectedTypes,
                    (v) => _selectedTypes = v),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: widget.title,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _openFilterSheet,
              ),
              if (_isFiltered)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: items.isEmpty
            ? Center(
                child: Text(
                  'No items found.',
                  style: AppTextStyle.regular14
                      .copyWith(color: AppColors.textSecondary),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: AppDimens.garmentCardWidth / AppDimens.garmentCardHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final g = items[i];
                  return GarmentCard(
                    garment: g,
                    isSelected: _pending?.id != null && _pending!.id == g.id,
                    onTap: () => setState(() => _pending = (_pending?.id == g.id) ? null : g),
                  );
                },
              ),
      ),
      bottomNavigationBar: BottomActionButton(
        label: 'Confirm',
        onPressed: () => Navigator.pop(context, SelectGarmentResult(_pending)),
      ),
    );
  }
}
