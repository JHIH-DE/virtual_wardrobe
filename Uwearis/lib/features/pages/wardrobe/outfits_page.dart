import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/providers/garments_provider.dart';
import '../../../core/providers/outfits_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/services/base_service.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/outfit_group.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/buttons/outfit_temperature_style_filter.dart';
import '../../widgets/common/overlays/ai_consent_dialog.dart';
import '../../widgets/common/overlays/error_dialog.dart';
import '../../widgets/common/overlays/feedback_overlay.dart';
import '../../widgets/common/wardrobe_nav_bar.dart';
import '../../widgets/common/wardrobe_tab_async.dart';
import '../../widgets/outfit/outfit_grid.dart';
import '../../widgets/outfit/outfit_insights_sheet.dart';
import 'create_outfit_page.dart';
import 'outfit_details_page.dart';

class OutfitsPage extends ConsumerStatefulWidget {
  const OutfitsPage({super.key});

  @override
  ConsumerState<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends ConsumerState<OutfitsPage> {
  final _filter = OutfitTemperatureStyleFilter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final report = wardrobeTabReporter(
        context,
        loadingLabel: AppLocalizations.of(context).loadingOutfitsEllipsis,
        tab: WardrobeTab.outfits,
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

  Future<void> _openAddOutfit() async {
    final l10n = AppLocalizations.of(context);
    WardrobeShellScope.of(context)?.setLoading(
      true,
      label: l10n.loadingGarmentsEllipsis,
      tab: WardrobeTab.outfits,
    );
    try {
      await ref.read(garmentsProvider.future);
      if (!mounted) return;
      WardrobeShellScope.of(
        context,
      )?.setLoading(false, tab: WardrobeTab.outfits);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateOutfitPage()),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      WardrobeShellScope.of(
        context,
      )?.setLoading(false, tab: WardrobeTab.outfits);
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
      if (!mounted) return;
      WardrobeShellScope.of(
        context,
      )?.setLoading(false, tab: WardrobeTab.outfits);
    } catch (e) {
      if (!mounted) return;
      WardrobeShellScope.of(
        context,
      )?.setLoading(false, tab: WardrobeTab.outfits);
      debugLog('Failed to load garments: $e');
      showErrorDialog(context, message: l10n.failedToLoadGarments);
    }
  }

  AppToolBar _buildAppBar(List<OutfitGroup> groups) {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.navOutfits,
      titleCount: _filter.applyToGroups(groups).length,
      centerTitle: false,
      showBackButton: false,
      actions: [
        if (groups.isNotEmpty)
          ActionDiscButton(
            tooltip: l10n.outfitInsights,
            icon: const Icon(
              Icons.bar_chart,
              size: ActionDisc.iconSize,
              color: AppColors.icon,
            ),
            onPressed: _openOutfitInsights,
          ),
        _filter.buildButton(l10n, [
          for (final g in groups) ...g.versions,
        ], onChanged: () => setState(() {})),
      ],
    );
  }

  /// The sheet's load runs the AI style analysis.
  Future<void> _openOutfitInsights() async {
    if (!await ensureAiConsent(context) || !mounted) return;
    showOutfitInsightsSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(outfitsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(groupsAsync.value ?? const []),
      body: groupsAsync.wardrobeTabBody(
        onRetry: () => ref.read(outfitsProvider.notifier).refresh(),
        data: (groups) => OutfitGrid(
          outfits: _filter.applyToGroups(groups),
          groupNameOf: (o) => groupOf(o, groups)?.name,
          onRefresh: () => ref.read(outfitsProvider.notifier).refresh(),
          emptyIcon: Icons.style_outlined,
          emptyTitle: AppLocalizations.of(context).noOutfitsYet,
          emptyMessage: AppLocalizations.of(context).outfitsEmptyHint,
          emptyActionLabel: AppLocalizations.of(context).createOutfit,
          onEmptyAction: _openAddOutfit,
          emptyBottomInset: AppDimens.navBarClearance,
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            AppDimens.navBarClearance,
          ),
          onOutfitTap: (outfit) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OutfitDetailsPage(
                outfit: outfit,
                group: groupOf(outfit, groups),
                versionFilter: _filter.versionFilter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
