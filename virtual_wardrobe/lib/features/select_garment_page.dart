import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../data/garment.dart';
import '../data/select_garment_result.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/deletable_card.dart';
import 'widgets/common/filter_button.dart';
import 'widgets/garment/garment_card.dart';

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
  late List<Garment> _garments;
  final _deleteGroup = DeletableCardGroup();

  @override
  void initState() {
    super.initState();
    _pending = widget.selected;
    _garments = [...widget.garments];
  }

  List<Garment> get _byCategory =>
      _garments.where((g) => g.category == widget.category).toList();

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

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: widget.title,
      actions: [
        FilterButton(
          isFiltered: _isFiltered,
          groups: [
            FilterGroup(
              label: 'Color',
              options: _availableColors,
              selected: () => _selectedColors,
              onToggle: (v) => setState(
                () => _selectedColors = FilterButton.toggleWithAll(
                  _selectedColors,
                  v,
                ),
              ),
            ),
            FilterGroup(
              label: 'Product Type',
              options: _availableTypes,
              selected: () => _selectedTypes,
              onToggle: (v) => setState(
                () => _selectedTypes = FilterButton.toggleWithAll(
                  _selectedTypes,
                  v,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBody() {
    final items = _filtered;
    if (items.isEmpty) return _buildEmptyState();
    return _buildGrid(items);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No items found.',
        style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildGrid(List<Garment> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: AppDimens.garmentCardHeight,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildGarmentCard(items[i]),
    );
  }

  Widget _buildGarmentCard(Garment g) {
    return DeletableCard(
      group: _deleteGroup,
      onDelete: () => _deleteGarment(g),
      child: GarmentCard(
        garment: g,
        isSelected: _pending?.id != null && _pending!.id == g.id,
        onTap: () =>
            setState(() => _pending = (_pending?.id == g.id) ? null : g),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomActionButton(
      label: 'Confirm',
      onPressed: () => Navigator.pop(context, SelectGarmentResult(_pending)),
    );
  }

  Future<void> _deleteGarment(Garment garment) async {
    final id = garment.id;
    if (id == null) return;
    try {
      await GarmentService().deleteGarment(id);
      if (!mounted) return;
      setState(() {
        _garments.removeWhere((g) => g.id == id);
        if (_pending?.id == id) _pending = null;
      });
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete garment')),
        );
      }
    }
  }
}
