import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/providers/outfits_provider.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/outfit_season_style_filter.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/main_tab_async.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/outfit/outfit_grid.dart';
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
        tab: AppTab.outfits,
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

  AppToolBar _buildAppBar(List<Outfit> all) {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.navOutfits,
      titleCount: _filter.apply(all).length,
      centerTitle: false,
      showBackButton: false,
      actions: [
        _filter.buildButton(l10n, onChanged: () => setState(() {})),
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
