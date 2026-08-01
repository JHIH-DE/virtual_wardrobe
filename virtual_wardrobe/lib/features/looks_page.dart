import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/look_service.dart';
import '../data/look.dart';
import '../l10n/generated/app_localizations.dart';
import 'look_details_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/favorite_card.dart';
import 'widgets/common/feedback_overlay.dart';
import 'widgets/common/filter_button.dart';
import 'widgets/common/floating_nav_bar.dart';
import 'widgets/look/look_card.dart';

class LooksPage extends ConsumerStatefulWidget {
  const LooksPage({super.key});

  @override
  ConsumerState<LooksPage> createState() => _LooksPageState();
}

class _LooksPageState extends ConsumerState<LooksPage> {
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
      _reportLoadingState(ref.read(looksProvider));
      ref.listenManual(looksProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
        _reportLoadingState(next);
      });
      ref.listenManual(lookFeedbackProvider, (_, next) {
        if (next == null) return;
        final l10n = AppLocalizations.of(context);
        showFeedbackOverlay(
          context,
          message: next == LookFeedbackKind.saved
              ? l10n.lookSaved
              : l10n.lookDeleted,
          imagePath: next == LookFeedbackKind.deleted
              ? 'assets/images/delete_success.png'
              : 'assets/images/success.png',
        );
        ref.read(lookFeedbackProvider.notifier).state = null;
      });
      ref.read(looksProvider.notifier).refreshIfNeeded();
    });
  }

  /// Mirrors looksProvider's loading state up to MainShell, which shows a
  /// full-screen overlay above the floating nav bar — see
  /// MainShellScope.setLoading for why this can't just be built inline.
  void _reportLoadingState(AsyncValue<List<Look>> state) {
    MainShellScope.of(context)?.setLoading(
      state.isLoading,
      label: AppLocalizations.of(context).loadingLooksEllipsis,
    );
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

  AppToolBar _buildAppBar(BuildContext context, List<Look> all) {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.navLooks,
      showBackButton: false,
      actions: [
        FilterButton(
          isFiltered: _isFiltered,
          count: _filtered(all).length,
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
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final looksAsync = ref.watch(looksProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(context, looksAsync.valueOrNull ?? []),
      body: looksAsync.when(
        // Shell-level overlay (see _reportLoadingState) covers the whole
        // screen including the nav bar while loading.
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorStateWidget(
          error: e,
          onRetry: () => ref.read(looksProvider.notifier).refresh(),
        ),
        data: (all) => _buildLooksGrid(_filtered(all)),
      ),
    );
  }

  Widget _buildLooksGrid(List<Look> looks) {
    if (looks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyStatePlaceholder(
            message: AppLocalizations.of(context).noLooksYet,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(looksProvider.notifier).refresh(),
      color: AppColors.primary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          AppDimens.floatingNavBarClearance,
        ),
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
          MaterialPageRoute(builder: (_) => LookDetailsPage(look: look)),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Look look) async {
    final next = !look.isFavorite;
    ref.read(looksProvider.notifier).updateFavorite(look.id, isFavorite: next);
    try {
      await LookService().setFavorite(look.id, isFavorite: next);
    } catch (e) {
      ref
          .read(looksProvider.notifier)
          .updateFavorite(look.id, isFavorite: !next);
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToUpdateFavorite),
          ),
        );
      }
    }
  }
}
