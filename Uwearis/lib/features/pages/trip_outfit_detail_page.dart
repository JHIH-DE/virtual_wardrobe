import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/trip_detail_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/image_cache_bust.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/trip_outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/fading_toolbar_title.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/cards/generated_image_card.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_list_card.dart';
import '../widgets/trip/trip_collection_actions.dart';
import 'outfit_edit_page.dart';
import '../../core/utils/remaining_try_ons.dart';
import '../../core/services/pending_try_on_store.dart';
import '../../core/utils/try_on_request.dart';
import '../widgets/common/overlays/try_on_dialogs.dart';
import '../widgets/common/overlays/error_dialog.dart';

enum _TripOutfitMenuAction { edit, keep, unkeep, remove }

/// One trip outfit opened from Trip Details' outfit grid: its try-on, missing
/// garments and garments, plus edit / keep / remove / try-on. Renders from
/// [tripDetailProvider], so every change shows on both pages at once.
class TripOutfitDetailPage extends ConsumerStatefulWidget {
  final int tripId;
  final int tripOutfitId;

  /// 1-based position in Trip Details' grid, for an unnamed outfit's title.
  final int index;

  const TripOutfitDetailPage({
    super.key,
    required this.tripId,
    required this.tripOutfitId,
    required this.index,
  });

  @override
  ConsumerState<TripOutfitDetailPage> createState() =>
      _TripOutfitDetailPageState();
}

class _TripOutfitDetailPageState extends ConsumerState<TripOutfitDetailPage>
    with TripCollectionActions, FadingToolbarTitle {
  bool _renderingOutfit = false;
  // A try-on whose outcome is unknown, by trip outfit id → its image before
  // the try-on. This endpoint takes no key, so a retry first re-reads the
  // trip, then asks before rendering (and charging) again.
  final Map<int, String> _unknownTryOns = {};
  // The outfit leaving the collection (removed here, or replaced by a
  // Refresh elsewhere) pops this page once.
  bool _popped = false;

  @override
  int get tripId => widget.tripId;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  TripOutfitCollection get _detail =>
      ref.read(tripDetailProvider(tripId)).value ??
      const TripOutfitCollection();

  TripOutfit? _findOutfit(TripOutfitCollection detail) {
    for (final o in detail.outfits) {
      if (o.id == widget.tripOutfitId) return o;
    }
    return null;
  }

  void _popOnce() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.pop(context);
  }

  /// A first render adds this trip outfit's own image; a re-render replaces
  /// it in place (same outfit id, so its image cache is bumped). The saved
  /// outfit it came from is never re-rendered.
  Future<void> _tryOn(TripOutfit outfit) async {
    await runCollectionAction(
      fallback: _l10n.failedToGenerateOutfit,
      request: () async {
        final unknownMarker = _unknownTryOns[outfit.id];
        if (unknownMarker != null) {
          final landed = await landedTripTryOn(
            tripId: tripId,
            tripOutfitId: outfit.id,
            beforeMarker: unknownMarker,
          );
          if (landed != null) {
            _unknownTryOns.remove(outfit.id);
            _bumpImage(outfit);
            return landed;
          }
          if (!mounted || !await showRetryWhileUnknownDialog(context)) {
            return null;
          }
          if (!mounted) return null;
        } else if (outfit.hasImage) {
          // A re-render spends a generation on top of the image shown.
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AppDialog(
              title: _l10n.regenerateOutfitConfirmTitle,
              body: _l10n.regenerateOutfitConfirmBody,
              primaryLabel: _l10n.regenerate,
              onPrimary: () => Navigator.pop(ctx, true),
              secondaryLabel: _l10n.cancel,
              onSecondary: () => Navigator.pop(ctx, false),
            ),
          );
          if (ok != true || !mounted) return null;
        }
        // Read before the await: the page may be gone when it lands.
        final overlay = Overlay.of(context, rootOverlay: true);
        final l10n = _l10n;
        final session = PendingTryOnStore.session;
        setState(() => _renderingOutfit = true);
        try {
          final collection = await sendTripTryOn(
            tripId: tripId,
            before: outfit,
            session: session,
            send: () =>
                TripService().tryOnTripOutfit(tripId, tripOutfitId: outfit.id),
          );
          _unknownTryOns.remove(outfit.id);
          if (PendingTryOnStore.session != session) return null;
          unawaited(announceRemainingTryOns(overlay, l10n));
          _bumpImage(outfit);
          return collection;
        } on TryOnStillRunning {
          _unknownTryOns[outfit.id] = tripOutfitImageMarker(outfit);
          if (mounted) {
            showErrorDialog(context, message: _l10n.tryOnOutcomeUnknown);
          }
          return null;
        } finally {
          if (mounted) setState(() => _renderingOutfit = false);
        }
      },
    );
  }

  void _bumpImage(TripOutfit outfit) {
    if (outfit.outfitId != null) {
      ImageCacheBust.bump(outfitImageCacheKey(outfit.outfitId!));
    }
  }

  /// Leaves mid-render; the render goes on and is applied if it lands.
  Future<void> _stopWaitingForTryOn() async {
    final stop = await showStopWaitingDialog(context);
    if (!stop || !mounted || !_renderingOutfit) return;
    Navigator.pop(context);
  }

  /// Picks from the packed, still-existing garments only.
  Future<void> _edit(TripOutfit outfit) async {
    if (isCollectionActionInFlight) return;
    final suitcase = _detail.suitcase.where((g) => !g.isDeleted).toList();
    final garmentIds = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitEditPage(
          initialGarments: outfit.garments,
          preloadedGarments: suitcase,
          validGarmentIds: {
            for (final g in suitcase)
              if (g.id != null) g.id!,
          },
          title: _l10n.editOutfitTitle,
        ),
      ),
    );
    if (garmentIds == null || !mounted) return;
    await runCollectionAction(
      fallback: _l10n.failedToUpdateDayOutfit,
      request: () => TripService().updateTripOutfit(
        tripId,
        tripOutfitId: outfit.id,
        garmentIds: garmentIds.toList(),
      ),
    );
  }

  Future<void> _togglePin(TripOutfit outfit) => runCollectionAction(
    fallback: _l10n.failedToUpdateDayOutfit,
    request: () => TripService().updateTripOutfit(
      tripId,
      tripOutfitId: outfit.id,
      isPinned: !outfit.isPinned,
    ),
  );

  Future<void> _remove(TripOutfit outfit) async {
    final removed = await runCollectionAction(
      fallback: _l10n.failedToRemoveTripOutfit,
      request: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AppDialog(
            title: _l10n.removeTripOutfitTitle,
            body: _l10n.removeTripOutfitBody,
            primaryLabel: _l10n.remove,
            onPrimary: () => Navigator.pop(ctx, true),
            secondaryLabel: _l10n.cancel,
            onSecondary: () => Navigator.pop(ctx, false),
          ),
        );
        if (confirmed != true) return null;
        return TripService().removeTripOutfit(tripId, tripOutfitId: outfit.id);
      },
    );
    if (removed) _popOnce();
  }

  /// Re-packs only the missing garments that still exist in the closet.
  Future<void> _packMissing(TripOutfit outfit) async {
    final ids = [
      for (final g in outfit.missingGarments(_detail.suitcaseIds))
        if (!g.isDeleted && g.id != null) g.id!,
    ];
    if (ids.isEmpty) return;
    final detailNotifier = ref.read(tripDetailProvider(tripId).notifier);
    await runCollectionAction(
      fallback: _l10n.failedToUpdateSuitcase,
      request: () async {
        final suitcase = await TripService().addSuitcaseItems(
          tripId,
          garmentIds: ids,
        );
        detailNotifier.setSuitcase(suitcase);
        // Saved-outfit candidates depend on the suitcase.
        unawaited(_reloadQuietly(detailNotifier));
        return null;
      },
    );
  }

  Future<void> _reloadQuietly(TripDetailNotifier notifier) async {
    try {
      await notifier.reloadTripDetail(syncSavedOutfits: true);
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Failed to reload trip outfits: $e');
    }
  }

  /// Re-fetches the collection for a freshly signed image URL.
  Future<String?> _refreshImageUrl() async {
    try {
      final collection = await TripService().getTripOutfits(tripId);
      return _findOutfit(collection)?.resultImageUrl;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail =
        ref.watch(tripDetailProvider(tripId)).value ??
        const TripOutfitCollection();
    final outfit = _findOutfit(detail);
    if (outfit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _popOnce());
      return const Scaffold(backgroundColor: AppColors.pageBackground);
    }
    final name = (outfit.name?.trim().isNotEmpty ?? false)
        ? outfit.name!
        : _l10n.tripOutfitFallbackName(widget.index);
    final missing = outfit.missingGarments(detail.suitcaseIds);
    final missingIds = {for (final g in missing) g.id};
    final canTryOn = missing.isEmpty && outfit.isComplete;
    final locked = isCollectionActionInFlight;

    // A system back mid-render takes the same Stop Waiting confirm.
    return PopScope(
      canPop: !_renderingOutfit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopWaitingForTryOn();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.pageBackground,
            appBar: AppToolBar(
              title: _l10n.outfitDetailsTitle,
              titleWidget: buildFadingToolbarTitle(name),
              actions: [_buildMenu(outfit, locked)],
            ),
            body: ListView(
              controller: toolbarTitleScrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // Same header shape as Outfit Details: name, then the image.
                Text(
                  name,
                  key: toolbarTitleAnchorKey,
                  style: AppTextStyle.bold22,
                ),
                const SizedBox(height: AppDimens.cardHeaderGap),
                GeneratedImageCard(
                  imageUrl: outfit.resultImageUrl,
                  hasAssignment: true,
                  isLoading: _renderingOutfit,
                  jobStatus: _l10n.generatingTryOnEllipsis,
                  errorLabel: _l10n.failedToLoadImage,
                  cacheKey: outfit.imageOutfitId == null
                      ? null
                      : outfitImageVersionedCacheKey(outfit.imageOutfitId!),
                  onRefreshUrl: _refreshImageUrl,
                  onRegenerate: canTryOn && !locked
                      ? () => _tryOn(outfit)
                      : null,
                  onGenerate: () => _tryOn(outfit),
                  generateLabel: _l10n.generateOutfit,
                  generateEnabled: canTryOn && !locked,
                  generateDisabledMessage: canTryOn
                      ? null
                      : missing.isNotEmpty
                      ? _l10n.tripOutfitMissingGarmentsTryOn
                      : _l10n.tripOutfitIncomplete,
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.cardSpacing),
                  _MissingGarmentsNotice(
                    missing: missing,
                    onPackMissing: locked ? null : () => _packMissing(outfit),
                    onEdit: locked ? null : () => _edit(outfit),
                  ),
                ],
                if (outfit.reasoning.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.sectionSpacing),
                  for (final line in outfit.reasoning)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: AppTextStyle.regular14.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppDimens.sectionSpacing),
                LabeledDivider(
                  label: _l10n.garmentsCount(outfit.garments.length),
                ),
                const SizedBox(height: AppDimens.cardHeaderGap),
                for (final g in outfit.garments)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimens.sectionSpacing,
                    ),
                    child: GarmentListCard(
                      garment: g,
                      isUnavailable: missingIds.contains(g.id),
                      onTap: () => GarmentDetailDialog.show(context, g),
                    ),
                  ),
              ],
            ),
          ),
          if (_renderingOutfit)
            Positioned.fill(
              child: LoadingOverlay(
                label: _l10n.generatingTryOnEllipsis,
                actionLabel: _l10n.stopWaiting,
                onAction: _stopWaitingForTryOn,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenu(TripOutfit outfit, bool locked) {
    return AppPopupMenu<_TripOutfitMenuAction>(
      variant: AppPopupMenuVariant.toolbar,
      onSelected: (action) => switch (action) {
        _TripOutfitMenuAction.edit => _edit(outfit),
        _TripOutfitMenuAction.keep ||
        _TripOutfitMenuAction.unkeep => _togglePin(outfit),
        _TripOutfitMenuAction.remove => _remove(outfit),
      },
      items: [
        AppPopupMenu.item(
          value: _TripOutfitMenuAction.edit,
          icon: Image.asset('assets/images/edit.png', width: 20, height: 20),
          label: _l10n.editOutfitTitle,
          enabled: !locked,
        ),
        if (outfit.source == TripOutfitSource.suggested)
          AppPopupMenu.item(
            value: outfit.isPinned
                ? _TripOutfitMenuAction.unkeep
                : _TripOutfitMenuAction.keep,
            icon: Icon(
              outfit.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
              color: AppColors.icon,
            ),
            label: outfit.isPinned ? _l10n.unkeepOutfit : _l10n.keepOutfit,
            enabled: !locked,
          ),
        AppPopupMenu.item(
          value: _TripOutfitMenuAction.remove,
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: AppColors.icon,
          ),
          label: _l10n.removeFromTrip,
          isDestructive: true,
          enabled: !locked,
        ),
      ],
    );
  }
}

class _MissingGarmentsNotice extends StatelessWidget {
  final List<Garment> missing;
  final VoidCallback? onPackMissing;
  final VoidCallback? onEdit;

  const _MissingGarmentsNotice({
    required this.missing,
    this.onPackMissing,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasDeleted = missing.any((g) => g.isDeleted);
    final canPack = missing.any((g) => !g.isDeleted);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.missingGarmentsCount(missing.length),
            style: AppTextStyle.semibold14.copyWith(color: AppColors.error),
          ),
          if (hasDeleted) ...[
            const SizedBox(height: 4),
            Text(
              l10n.missingGarmentsDeletedHint,
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canPack)
                AccentPillButton(
                  label: l10n.addToSuitcase,
                  onPressed: onPackMissing,
                ),
              AccentPillButton(label: l10n.editOutfitTitle, onPressed: onEdit),
            ],
          ),
        ],
      ),
    );
  }
}
