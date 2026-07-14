import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/services/auth_handler.dart';
import '../core/services/look_service.dart';
import '../core/utils/debug_log.dart';
import '../data/look.dart';
import 'looks_details_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/deletable_card.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
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
  final _deleteGroup = DeletableCardGroup();

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
    return AppToolBar(
      title: 'Used in Looks',
      actions: [
        FilterButton(
          isFiltered: _isFiltered,
          groups: [
            FilterGroup(
              label: 'Season',
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
              label: 'Style',
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
      backgroundColor: AppColors.defaultBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ErrorStateWidget(error: _error!, onRetry: _load)
            : _buildLooksGrid(_filtered()),
      ),
    );
  }

  Widget _buildLooksGrid(List<Look> looks) {
    if (looks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const EmptyStatePlaceholder(
            message: 'This item has not been used in any looks yet.',
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
        itemBuilder: (context, index) {
          final look = looks[index];
          return DeletableCard(
            group: _deleteGroup,
            borderRadius: BorderRadius.circular(20),
            onDelete: () => _deleteLook(look),
            child: LookCard(
              look: look,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LooksDetailsPage(look: look)),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteLook(Look look) async {
    try {
      await LookService().deleteLook(look.id);
      if (!mounted) return;
      setState(() => _allLooks.removeWhere((l) => l.id == look.id));
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete look')));
      }
    }
  }
}
