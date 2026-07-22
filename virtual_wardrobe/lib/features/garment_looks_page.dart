import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/services/auth_handler.dart';
import '../core/services/look_service.dart';
import '../core/utils/debug_log.dart';
import '../data/look.dart';
import '../l10n/generated/app_localizations.dart';
import 'looks_details_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/favorite_card.dart';
import 'widgets/common/filter_button.dart';
import 'widgets/look/look_card.dart';

class GarmentLooksPage extends StatefulWidget {
  final int garmentId;

  const GarmentLooksPage({super.key, required this.garmentId});

  @override
  State<GarmentLooksPage> createState() => _GarmentLooksPageState();
}

class _GarmentLooksPageState extends State<GarmentLooksPage> {
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
    'Street',
    'Classic',
    'Sporty',
  ];

  Set<String> _selectedSeasons = {'All'};
  Set<String> _selectedStyle = {'All'};

  List<Look> _allLooks = [];
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
      debugLog('getLooksByGarments garmentId=${widget.garmentId}');
      final result = await LookService().getLooksByGarments([widget.garmentId]);
      final saved = result.where((l) => l.isSaved).toList();
      debugLog(
        'API returned ${result.length} looks, ${saved.length} isSaved=true',
      );
      for (final l in result) {
        debugLog(
          '  look id=${l.id} isSaved=${l.isSaved} imageUrl=${l.imageUrl}',
        );
      }
      if (!mounted) return;
      setState(() => _allLooks = saved);
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

  List<Look> _filtered() {
    return _allLooks.where((l) {
      final okSeason =
          _selectedSeasons.contains('All') ||
          l.seasons.any(
            (s) => _selectedSeasons.any(
              (sel) => sel.toLowerCase() == s.toLowerCase(),
            ),
          );
      final okStyle =
          _selectedStyle.contains('All') ||
          l.style.any(
            (s) => _selectedStyle.any(
              (sel) => sel.toLowerCase() == s.toLowerCase(),
            ),
          );
      return okSeason && okStyle;
    }).toList();
  }

  AppToolBar _buildAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.usedInLooks,
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorStateWidget(error: _error!, onRetry: _load)
          : _buildLooksGrid(_filtered()),
    );
  }

  Widget _buildLooksGrid(List<Look> looks) {
    if (looks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyStatePlaceholder(
            message: AppLocalizations.of(context).itemNotUsedInLooksYet,
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
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: AppDimens.lookCardHeight,
        ),
        itemCount: looks.length,
        itemBuilder: (context, index) => _buildLookCard(context, looks[index]),
      ),
    );
  }

  Widget _buildLookCard(BuildContext context, Look look) {
    return FavoriteCard(
      isFavorite: look.isFavorite,
      onToggle: () => _toggleFavorite(look),
      child: LookCard(
        look: look,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LooksDetailsPage(look: look)),
        ),
      ),
    );
  }

  void _setLookFavorite(int lookId, bool isFavorite) {
    setState(() {
      _allLooks = _allLooks
          .map((l) => l.id == lookId ? l.copyWith(isFavorite: isFavorite) : l)
          .toList();
    });
  }

  Future<void> _toggleFavorite(Look look) async {
    final next = !look.isFavorite;
    _setLookFavorite(look.id, next);
    try {
      await LookService().setFavorite(look.id, isFavorite: next);
    } catch (e) {
      if (!mounted) return;
      _setLookFavorite(look.id, !next);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToUpdateFavorite),
        ),
      );
    }
  }
}
