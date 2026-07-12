import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../data/garment.dart';
import '../data/select_garment_result.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/garment/garment_card.dart';
import 'widgets/garment/garment_filter_button.dart';

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
    final colors =
        _byCategory
            .map((g) => g.color)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...colors];
  }

  List<String> get _availableTypes {
    final types =
        _byCategory
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
      final okColor =
          _selectedColors.contains('All') ||
          (g.color != null &&
              _selectedColors.any(
                (c) => c.toLowerCase() == g.color!.toLowerCase(),
              ));
      final okType =
          _selectedTypes.contains('All') ||
          _selectedTypes.any(
            (t) => t.toLowerCase() == g.subCategory.toLowerCase(),
          );
      return okColor && okType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: widget.title,
        actions: [
          GarmentFilterButton(
            isFiltered: _isFiltered,
            availableColors: _availableColors,
            availableTypes: _availableTypes,
            selectedColors: () => _selectedColors,
            selectedTypes: () => _selectedTypes,
            onColorsChanged: (v) => setState(() => _selectedColors = v),
            onTypesChanged: (v) => setState(() => _selectedTypes = v),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: items.isEmpty
            ? Center(
                child: Text(
                  'No items found.',
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 8,
                  mainAxisExtent: AppDimens.garmentCardHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final g = items[i];
                  return GarmentCard(
                    garment: g,
                    isSelected: _pending?.id != null && _pending!.id == g.id,
                    onTap: () => setState(
                      () => _pending = (_pending?.id == g.id) ? null : g,
                    ),
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
