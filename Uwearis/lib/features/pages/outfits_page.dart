import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/utils/debug_log.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/outfit_season_style_filter.dart';
import '../widgets/common/main_nav_bar.dart';
import '../widgets/common/main_tab_async.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/outfit/outfit_grid.dart';
import 'add_outfit_page.dart';
import 'outfit_details_page.dart';

class OutfitsPage extends ConsumerStatefulWidget {
  const OutfitsPage({super.key});

  @override
  ConsumerState<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends ConsumerState<OutfitsPage> {
  final _filter = OutfitSeasonStyleFilter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final report = mainTabReporter(
        context,
        loadingLabel: AppLocalizations.of(context).loadingOutfitsEllipsis,
        tab: MainTab.outfits,
      );
      report(ref.read(outfitsProvider));
      ref.listenManual(outfitsProvider, (_, next) => report(next));
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

  /// Triggered by the empty-state "Create Outfit" CTA — mirrors
  /// [main_shell.dart]'s own `QuickAction.addOutfit` (warm garmentsProvider,
  /// then push [AddOutfitPage]), routed through [MainShellScope]'s
  /// per-tab loading overlay since this page is itself a main tab (see
  /// CLAUDE.md's main-tab loading convention) rather than a page-local one.
  Future<void> _openAddOutfit() async {
    final l10n = AppLocalizations.of(context);
    MainShellScope.of(
      context,
    )?.setLoading(true, label: l10n.loadingGarments, tab: MainTab.outfits);
    try {
      await ref.read(garmentsProvider.future);
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: MainTab.outfits);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddOutfitPage()),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: MainTab.outfits);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: MainTab.outfits);
      debugLog('Failed to load garments: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.failedToLoadGarments)));
    }
  }

  AppToolBar _buildAppBar(List<Outfit> all) {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.navOutfits,
      titleCount: _filter.apply(all).length,
      centerTitle: false,
      showBackButton: false,
      actions: [
        _filter.buildButton(l10n, all, onChanged: () => setState(() {})),
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
      body: outfitsAsync.mainTabBody(
        onRetry: () => ref.read(outfitsProvider.notifier).refresh(),
        data: (all) => OutfitGrid(
          outfits: _filter.apply(all),
          onRefresh: () => ref.read(outfitsProvider.notifier).refresh(),
          emptyIcon: Icons.style_outlined,
          emptyTitle: AppLocalizations.of(context).noOutfitsYet,
          emptyMessage: AppLocalizations.of(context).outfitsEmptyHint,
          emptyActionLabel: AppLocalizations.of(context).createOutfit,
          onEmptyAction: _openAddOutfit,
          emptyBottomInset: AppDimens.mainNavBarClearance,
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            AppDimens.mainNavBarClearance,
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
