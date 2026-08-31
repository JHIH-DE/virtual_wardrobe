import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/filter_button.dart';
import '../widgets/common/images/petal_loader.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/outfit/outfit_card.dart';
import 'outfit_details_page.dart';

class GarmentOutfitsPage extends StatefulWidget {
  final int garmentId;

  const GarmentOutfitsPage({super.key, required this.garmentId});

  @override
  State<GarmentOutfitsPage> createState() => _GarmentOutfitsPageState();
}

class _GarmentOutfitsPageState extends State<GarmentOutfitsPage> {
  static const List<String> _seasons = [
    'All',
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];
  static const List<String> _styles = [
    'All',
    'Minimal',
    'Classic',
    'Smart Casual',
    'Streetwear',
    'Athleisure',
    'Workwear',
    'Preppy',
    'Business',
    'Vintage',
  ];

  Set<String> _selectedSeasons = {'All'};
  Set<String> _selectedStyle = {'All'};

  List<Outfit> _allOutfits = [];
  bool _loading = true;
  String? _error;

  bool get _isFiltered =>
      !_selectedSeasons.contains('All') || !_selectedStyle.contains('All');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugLog('getOutfitsByGarments garmentId=${widget.garmentId}');
      final result = await OutfitService().getOutfitsByGarments([
        widget.garmentId,
      ]);
      // `is_saved` is no longer part of the outfit schema this endpoint
      // returns (always parses false), so filtering by it excluded every
      // result — show everything getOutfitsByGarments actually found.
      if (!mounted) return;
      setState(() => _allOutfits = result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Outfit> _filtered() {
    return _allOutfits.where((o) {
      final okSeason =
          _selectedSeasons.contains('All') ||
          o.seasons.any(
            (s) => _selectedSeasons.any(
              (sel) => sel.toLowerCase() == s.toLowerCase(),
            ),
          );
      final okStyle =
          _selectedStyle.contains('All') ||
          o.style.any(
            (s) => _selectedStyle.any(
              (sel) => _normalizeStyle(sel) == _normalizeStyle(s),
            ),
          );
      return okSeason && okStyle;
    }).toList();
  }

  // The backend's style tags are snake_case (`smart_casual`) while the
  // filter chips show Title Case with spaces ("Smart Casual") — normalize
  // both sides to compare regardless of separator/case.
  String _normalizeStyle(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');

  AppToolBar _buildAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.usedInOutfits,
      actions: [
        FilterButton(
          isFiltered: _isFiltered,
          groups: [
            FilterGroup(
              label: l10n.seasonLabel,
              options: _seasons,
              selected: () => _selectedSeasons,
              onToggle: (s) => setState(
                () => _selectedSeasons = FilterButton.toggleWithAll(
                  _selectedSeasons,
                  s,
                ),
              ),
            ),
            FilterGroup(
              label: l10n.styleLabel,
              options: _styles,
              selected: () => _selectedStyle,
              onToggle: (s) => setState(
                () => _selectedStyle = FilterButton.toggleWithAll(
                  _selectedStyle,
                  s,
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
      body: _loading
          ? const Center(child: PetalLoader())
          : _error != null
          ? ErrorStateWidget(error: _error!, onRetry: _load)
          : _buildOutfitsGrid(_filtered()),
    );
  }

  Widget _buildOutfitsGrid(List<Outfit> outfits) {
    if (outfits.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyStatePlaceholder(
            message: AppLocalizations.of(context).itemNotUsedInOutfitsYet,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppDimens.cardSpacing,
          mainAxisSpacing: AppDimens.cardSpacing,
          mainAxisExtent: AppDimens.outfitCardHeight,
        ),
        itemCount: outfits.length,
        itemBuilder: (context, index) =>
            _buildOutfitCard(context, outfits[index]),
      ),
    );
  }

  Widget _buildOutfitCard(BuildContext context, Outfit outfit) {
    return OutfitCard(
      outfit: outfit,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OutfitDetailsPage(outfit: outfit)),
      ),
    );
  }
}
