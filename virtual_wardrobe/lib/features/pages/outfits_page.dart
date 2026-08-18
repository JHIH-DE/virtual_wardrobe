import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import 'outfit_details_page.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/common/cards/count_pill.dart';
import '../widgets/common/buttons/filter_button.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/outfit/outfit_card.dart';

class OutfitsPage extends ConsumerStatefulWidget {
  const OutfitsPage({super.key});

  @override
  ConsumerState<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends ConsumerState<OutfitsPage> {
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
      _reportLoadingState(ref.read(outfitsProvider));
      ref.listenManual(outfitsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
        _reportLoadingState(next);
      });
      ref.listenManual(outfitFeedbackProvider, (_, next) {
        if (next == null) return;
        final l10n = AppLocalizations.of(context);
        showFeedbackOverlay(
          context,
          message: next == OutfitFeedbackKind.saved
              ? l10n.outfitSaved
              : l10n.outfitDeleted,
          imagePath: next == OutfitFeedbackKind.deleted
              ? 'assets/images/delete_success.png'
              : 'assets/images/success.png',
        );
        ref.read(outfitFeedbackProvider.notifier).state = null;
      });
      ref.read(outfitsProvider.notifier).refreshIfNeeded();
    });
  }

  /// Mirrors outfitsProvider's loading state up to MainShell, which shows a
  /// full-screen overlay above the floating nav bar — see
  /// MainShellScope.setLoading for why this can't just be built inline.
  void _reportLoadingState(AsyncValue<List<Outfit>> state) {
    MainShellScope.of(context)?.setLoading(
      state.isLoading,
      label: AppLocalizations.of(context).loadingOutfitsEllipsis,
    );
  }

  bool get _isFiltered =>
      !_selectedSeasons.contains('All') || !_selectedStyle.contains('All');

  List<Outfit> _filtered(List<Outfit> all) {
    return all.where((o) {
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
              (sel) => sel.toLowerCase() == s.toLowerCase(),
            ),
          );
      return okSeason && okStyle;
    }).toList();
  }

  AppToolBar _buildAppBar(BuildContext context, List<Outfit> all) {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.navOutfits,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.navOutfits,
            textScaler: TextScaler.noScaling,
            style: AppTextStyle.bold18,
          ),
          const SizedBox(width: 8),
          CountPill(count: _filtered(all).length),
        ],
      ),
      centerTitle: false,
      showBackButton: false,
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
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final outfitsAsync = ref.watch(outfitsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(context, outfitsAsync.valueOrNull ?? []),
      body: outfitsAsync.when(
        // Shell-level overlay (see _reportLoadingState) covers the whole
        // screen including the nav bar while loading.
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorStateWidget(
          error: e,
          onRetry: () => ref.read(outfitsProvider.notifier).refresh(),
        ),
        data: (all) => _buildOutfitsGrid(_filtered(all)),
      ),
    );
  }

  Widget _buildOutfitsGrid(List<Outfit> outfits) {
    if (outfits.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyStatePlaceholder(
            message: AppLocalizations.of(context).noOutfitsYet,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(outfitsProvider.notifier).refresh(),
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
