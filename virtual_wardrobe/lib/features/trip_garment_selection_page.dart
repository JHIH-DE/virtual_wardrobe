import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/trip_plan_service.dart';
import '../core/utils/debug_log.dart';
import '../data/garment.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/card_corner_badge.dart';
import 'widgets/common/category_selector.dart';
import 'widgets/common/info_banner.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/garment/garment_card.dart';
import 'widgets/garment/garment_filter_button.dart';

class _CategoryAdvice {
  final int recommendedQuantity;
  final String reasoning;
  final Set<int> suggestedGarmentIds;

  const _CategoryAdvice({
    required this.recommendedQuantity,
    required this.reasoning,
    required this.suggestedGarmentIds,
  });
}

class TripGarmentSelectionPage extends StatefulWidget {
  final int tripId;
  final List<Garment> garments;
  final Set<int> initiallySelectedIds;

  const TripGarmentSelectionPage({
    super.key,
    required this.tripId,
    required this.garments,
    required this.initiallySelectedIds,
  });

  @override
  State<TripGarmentSelectionPage> createState() =>
      _TripGarmentSelectionPageState();
}

class _TripGarmentSelectionPageState extends State<TripGarmentSelectionPage> {
  static const _categories = [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outer,
    GarmentCategory.onePiece,
    GarmentCategory.shoes,
    GarmentCategory.socks,
    GarmentCategory.accessory,
  ];

  late final Set<int> _selectedIds = {...widget.initiallySelectedIds};
  late final List<GarmentCategory> _availableCategories = _categories
      .where((c) => widget.garments.any((g) => g.category == c))
      .toList();
  late GarmentCategory _selectedCategory = _availableCategories.isEmpty
      ? GarmentCategory.top
      : _availableCategories.first;
  final Map<GarmentCategory, _CategoryAdvice> _adviceByCategory = {};
  bool _loadingAdvice = true;
  bool _reasoningExpanded = false;

  Set<String> _selectedColors = {'All'};
  Set<String> _selectedTypes = {'All'};

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    try {
      final data = await TripPlanService().getTripSuggestion(widget.tripId);
      final categories = data['categories'];
      if (categories is List) {
        for (final item in categories) {
          if (item is! Map) continue;
          final category = GarmentCategoryX.fromApiValue(
            item['category'] as String?,
          );
          final suggestedIds = item['suggested_garment_ids'];
          _adviceByCategory[category] = _CategoryAdvice(
            recommendedQuantity: (item['recommended_quantity'] as num?)
                    ?.toInt() ??
                0,
            reasoning: item['reasoning'] as String? ?? '',
            suggestedGarmentIds: suggestedIds is List
                ? suggestedIds.whereType<int>().toSet()
                : {},
          );
        }
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load packing advice: $e');
    } finally {
      if (mounted) setState(() => _loadingAdvice = false);
    }
  }

  void _toggle(Garment garment) {
    final id = garment.id;
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  List<Garment> get _byCategory =>
      widget.garments.where((g) => g.category == _selectedCategory).toList();

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
    final advice = _adviceByCategory[_selectedCategory];
    final items = _filtered;
    if (advice != null) {
      items.sort((a, b) {
        final aSuggested = advice.suggestedGarmentIds.contains(a.id) ? 0 : 1;
        final bSuggested = advice.suggestedGarmentIds.contains(b.id) ? 0 : 1;
        return aSuggested.compareTo(bSuggested);
      });
    }
    final selectedInCategory = _byCategory
        .where((g) => _selectedIds.contains(g.id))
        .length;

    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: 'Select Garments',
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
        child: Column(
          children: [
            CategorySelector(
              categories: _availableCategories,
              selectedCategory: _selectedCategory,
              onSelected: (category) => setState(() {
                _selectedCategory = category;
                _selectedColors = {'All'};
                _selectedTypes = {'All'};
                _reasoningExpanded = false;
              }),
            ),
            if (_loadingAdvice || advice != null)
              _buildAdviceBanner(advice, selectedInCategory),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No garments in ${_selectedCategory.label}',
                        style: AppTextStyle.regular16.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: AppDimens.garmentCardHeight,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final g = items[i];
                        final selected = _selectedIds.contains(g.id);
                        final suggested =
                            advice?.suggestedGarmentIds.contains(g.id) ??
                            false;
                        return Stack(
                          children: [
                            GarmentCard(
                              garment: g,
                              isSelected: selected,
                              onTap: () => _toggle(g),
                            ),
                            if (suggested)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: CardCornerBadge(
                                  icon: Icons.auto_awesome,
                                  backgroundColor: AppColors.primary,
                                  iconColor: Colors.white,
                                  onTap: () => ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        advice?.reasoning ??
                                            'Suggested by AI',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionButton(
        label: 'Confirm',
        onPressed: () => Navigator.pop(context, _selectedIds),
      ),
    );
  }

  Widget _buildAdviceBanner(_CategoryAdvice? advice, int selectedInCategory) {
    return InfoBanner(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: _loadingAdvice
          ? Text(
              'Loading packing suggestions...',
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          : _buildAdviceContent(advice!, selectedInCategory),
    );
  }

  Widget _buildAdviceContent(_CategoryAdvice advice, int selectedInCategory) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: advice.reasoning.isEmpty
          ? null
          : () => setState(() => _reasoningExpanded = !_reasoningExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recommended ${advice.recommendedQuantity} · '
                  'Selected $selectedInCategory',
                  style: AppTextStyle.bold14,
                ),
              ),
              if (advice.reasoning.isNotEmpty)
                AnimatedRotation(
                  turns: _reasoningExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _reasoningExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                advice.reasoning,
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
