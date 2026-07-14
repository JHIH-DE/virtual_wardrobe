import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/providers/garments_provider.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/look_service.dart';
import '../data/look.dart';
import 'looks_details_page.dart';
import 'manual_try_on_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/deletable_card.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/filter_button.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/look/look_card.dart';

class LooksPage extends ConsumerStatefulWidget {
  const LooksPage({super.key});

  @override
  ConsumerState<LooksPage> createState() => _LooksPageState();
}

class _LooksPageState extends ConsumerState<LooksPage> {
  bool _openingTryOn = false;
  final _deleteGroup = DeletableCardGroup();

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(looksProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
      ref.read(looksProvider.notifier).refreshIfNeeded();
    });
  }

  bool get _isFiltered =>
      !_selectedSeasons.contains('All') || !_selectedStyle.contains('All');

  List<Look> _filtered(List<Look> all) {
    return all.where((l) {
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

  AppToolBar _buildAppBar(BuildContext context) {
    return AppToolBar(
      title: 'Looks',
      backgroundColor: AppColors.surface,
      showBackButton: false,
      leading: IconButton(
        icon: Image.asset(
          'assets/images/plus.png',
          height: AppDimens.iconMediumSize,
        ),
        onPressed: () => _handleOpenManualTryOn(context),
      ),
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
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final looksAsync = ref.watch(looksProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.defaultBackground,
          appBar: _buildAppBar(context),
          body: looksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
              error: e,
              onRetry: () => ref.read(looksProvider.notifier).refresh(),
            ),
            data: (all) => _buildLooksGrid(_filtered(all)),
          ),
        ),
        if (_openingTryOn)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Garments...'),
          ),
      ],
    );
  }

  Widget _buildLooksGrid(List<Look> looks) {
    if (looks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const EmptyStatePlaceholder(message: 'No looks yet.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(looksProvider.notifier).refresh(),
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
      ref.read(looksProvider.notifier).removeById(look.id);
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

  Future<void> _handleOpenManualTryOn(BuildContext context) async {
    setState(() => _openingTryOn = true);
    try {
      final garments = await ref.read(garmentsProvider.future);
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualTryOnPage(preloadedGarments: garments),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load garments')),
        );
      }
    }
  }
}
