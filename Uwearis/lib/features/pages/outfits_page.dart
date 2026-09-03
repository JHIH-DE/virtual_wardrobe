import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../data/outfit.dart';
import '../../data/style_type.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/filter_button.dart';
import '../widgets/common/cards/count_pill.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/outfit/outfit_grid.dart';
import 'outfit_details_page.dart';

class OutfitsPage extends ConsumerStatefulWidget {
  const OutfitsPage({super.key});

  @override
  ConsumerState<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends ConsumerState<OutfitsPage> {
  static const List<String> _seasons = ['All', ...seasonOptions];
  static const List<String> _styles = ['All', ...styleOptions];

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
      tab: AppTab.outfits,
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

  AppToolBar _buildAppBar(List<Outfit> all) {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.navOutfits,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.navOutfits,
            textScaler: TextScaler.noScaling,
            style: AppTextStyle.bold20,
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
    final outfitsAsync = ref.watch(outfitsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(outfitsAsync.value ?? []),
      body: outfitsAsync.when(
        // Shell-level overlay (see _reportLoadingState) covers the whole
        // screen including the nav bar while loading.
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorStateWidget(
          error: e,
          onRetry: () => ref.read(outfitsProvider.notifier).refresh(),
        ),
        data: (all) => OutfitGrid(
          outfits: _filtered(all),
          onRefresh: () => ref.read(outfitsProvider.notifier).refresh(),
          emptyMessage: AppLocalizations.of(context).noOutfitsYet,
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            AppDimens.floatingNavBarClearance,
          ),
          onOutfitTap: (outfit) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OutfitDetailsPage(outfit: outfit),
            ),
          ),
        ),
      ),
    );
  }
}
