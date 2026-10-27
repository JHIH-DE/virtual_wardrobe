import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/trip_detail_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/trip.dart';
import '../../data/trip_plan.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/buttons/action_disc_button.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/removable_card.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';
import '../widgets/trip/replan_confirm_dialog.dart';
import 'trip_garment_selection_page.dart';
import 'trip_outfit_selection_page.dart';

class TripSuitcasePage extends ConsumerStatefulWidget {
  final Trip trip;

  const TripSuitcasePage({super.key, required this.trip});

  @override
  ConsumerState<TripSuitcasePage> createState() => _TripSuitcasePageState();
}

class _TripSuitcasePageState extends ConsumerState<TripSuitcasePage> {
  static const _categoryOrder = [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outer,
    GarmentCategory.onePiece,
    GarmentCategory.shoes,
    GarmentCategory.socks,
    GarmentCategory.accessory,
  ];

  late bool _loading = !_hasCachedDetail;
  // Staged list: picker changes land here without hitting the server;
  // per-card removals commit immediately (they have their own confirm).
  List<Garment> _packedGarments = [];
  Set<int> _committedIds = {};
  // Fixed baseline for [_garmentsChangedSinceOpen].
  Set<int> _initialPackedIds = {};
  bool _committing = false;
  final Set<int> _pendingIds = {};
  final _deleteGroup = RemovableCardGroup();

  bool _generatingPlan = false;
  // Covers the confirm dialog and commit too, not just the AI call.
  bool _planActionInFlight = false;

  Set<int> get _packedIds => {
    for (final g in _packedGarments)
      if (g.id != null) g.id!,
  };

  bool get _isDirty => !setEquals(_packedIds, _committedIds);

  bool get _garmentsChangedSinceOpen =>
      !setEquals(_packedIds, _initialPackedIds);

  int get _tripId => int.parse(widget.trip.id);

  AsyncValue<TripDetail> get _detailState =>
      ref.read(tripDetailProvider(_tripId));

  bool get _hasCachedDetail => _detailState.hasValue && !_detailState.hasError;

  TripDetailNotifier get _detailNotifier =>
      ref.read(tripDetailProvider(_tripId).notifier);

  bool get _hasTripPlan => _detailState.value?.hasTripPlan ?? false;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Mirrors the backend's `/generate` minimum (top + bottom or one-piece,
  /// plus shoes; else `SUITCASE_INCOMPLETE`). UX only — the backend decides.
  bool _hasViableSuitcase(List<Garment> suitcase) {
    final categories = suitcase.map((g) => g.category).toSet();
    final hasTopAndBottom =
        categories.contains(GarmentCategory.top) &&
        categories.contains(GarmentCategory.bottom);
    final hasOnePiece = categories.contains(GarmentCategory.onePiece);
    final hasShoes = categories.contains(GarmentCategory.shoes);
    return (hasTopAndBottom || hasOnePiece) && hasShoes;
  }

  /// Staged pieces count: [_generatePlan] commits them before planning.
  bool get _isSuitcaseViable => _hasViableSuitcase(_packedGarments);

  /// A replan is only offered once the suitcase changed since opening.
  bool get _showsBottomActionButton =>
      !_generatingPlan &&
      !_planActionInFlight &&
      !_committing &&
      _isSuitcaseViable &&
      (!_hasTripPlan || _garmentsChangedSinceOpen);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchAuthExpiry(garmentsProvider);
      _watchAuthExpiry(outfitsProvider);
      // Also keeps the detail provider alive while a first load retries.
      _watchAuthExpiry(tripDetailProvider(_tripId));
      ref.read(garmentsProvider.notifier).refreshIfNeeded();
      ref.read(outfitsProvider.notifier).refreshIfNeeded();
    });
    if (_hasCachedDetail) {
      _applySuitcase(_detailState.requireValue.suitcase);
    } else {
      _loadPackedItems();
    }
  }

  void _watchAuthExpiry<T>(ProviderListenable<AsyncValue<T>> provider) {
    ref.listenManual<AsyncValue<T>>(provider, (_, next) {
      if (next.hasError && next.error is AuthExpiredException) {
        AuthExpiredHandler.handle(context);
      }
    });
  }

  void _applySuitcase(List<Garment> garments) {
    _packedGarments = List.of(garments);
    _committedIds = {
      for (final g in garments)
        if (g.id != null) g.id!,
    };
    _initialPackedIds = {..._committedIds};
  }

  /// Without [reload], waits on [tripDetailProvider]'s first load; with it
  /// (pull to refresh), re-fetches the suitcase.
  Future<void> _loadPackedItems({bool reload = false}) async {
    try {
      final garments = reload
          ? await _detailNotifier.reloadSuitcase()
          : (await ref.read(tripDetailProvider(_tripId).future)).suitcase;
      if (mounted) setState(() => _applySuitcase(garments));
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to load suitcase items: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAddGarment(List<Garment> allGarments) async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
    if (!mounted) return;
    final garments = (ref.read(garmentsProvider).value ?? allGarments).active;

    final result = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => TripGarmentSelectionPage(
          tripId: _tripId,
          garments: garments,
          initiallySelectedIds: _packedIds,
        ),
      ),
    );
    if (result == null) return;

    final toAdd = result.difference(_packedIds);
    final toRemove = _packedIds.difference(result);
    if (toAdd.isEmpty && toRemove.isEmpty) return;

    // Staged only — committed by Plan/Replan or on leaving the page.
    final closetById = _indexGarmentsById(garments);
    setState(() {
      _packedGarments = [
        for (final g in _packedGarments)
          if (!toRemove.contains(g.id)) g,
        for (final id in toAdd)
          if (closetById[id] != null) closetById[id]!,
      ];
    });
  }

  /// Stages a saved outfit's garments that are still in the closet and not
  /// packed yet.
  Future<void> _addFromOutfit() async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
    if (!mounted) return;
    final outfit = await Navigator.push<Outfit>(
      context,
      MaterialPageRoute(
        builder: (_) => TripOutfitSelectionPage(packedGarmentIds: _packedIds),
      ),
    );
    if (outfit == null || !mounted) return;

    final closetById = _indexGarmentsById(
      (ref.read(garmentsProvider).value ?? const <Garment>[]).active,
    );
    final packedIds = _packedIds;
    final newGarments = [
      for (final id in outfit.garmentIds.toSet())
        if (!packedIds.contains(id) && closetById[id] != null) closetById[id]!,
    ];

    if (newGarments.isEmpty) return;
    setState(() => _packedGarments = [..._packedGarments, ...newGarments]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n.addedItemsFromOutfitCount(newGarments.length)),
      ),
    );
  }

  /// Returns false on failure, leaving the changes staged.
  Future<bool> _commitChanges() async {
    if (_committing || !_isDirty) return true;
    final toAdd = _packedIds.difference(_committedIds);
    final toRemove = _committedIds.difference(_packedIds);
    final committed = List.of(_packedGarments);
    final byId = {
      for (final g in committed)
        if (g.id != null) g.id!: g,
    };
    // Tracks each request as it lands, so a failure midway still records
    // what the server already has and a retry doesn't resend it.
    final committedNow = {..._committedIds};
    final detailNotifier = _detailNotifier;
    setState(() => _committing = true);
    try {
      for (final id in toAdd) {
        await TripService().addSuitcaseItem(_tripId, garmentId: id);
        committedNow.add(id);
        detailNotifier.addSuitcaseGarments([?byId[id]]);
      }
      for (final id in toRemove) {
        await TripService().removeSuitcaseItem(_tripId, garmentId: id);
        committedNow.remove(id);
        detailNotifier.removeSuitcaseGarment(id);
      }
      detailNotifier.setSuitcase(committed);
      return true;
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return false;
    } catch (e) {
      debugLog('Failed to update suitcase: $e');
      if (mounted) {
        showErrorDialog(context, message: _l10n.failedToUpdateSuitcase);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _committedIds = committedNow;
          _committing = false;
        });
      }
    }
  }

  /// Silently commits staged changes before popping; stays on failure.
  Future<void> _leaveWithCommit() async {
    if (_committing) return;
    if (_isDirty && !await _commitChanges()) return;
    if (mounted) Navigator.pop(context);
  }

  /// First plan: generates every day. Replan: only the days
  /// [daysToReplan] picks; nothing is called if none need it. On success,
  /// reloads the plan before popping so Trip Details already shows it.
  Future<void> _generatePlan() async {
    if (_planActionInFlight) return;
    setState(() => _planActionInFlight = true);
    try {
      if (_hasTripPlan) {
        final confirmed = await showReplanConfirmDialog(context);
        if (!confirmed || !mounted) return;
      }

      // Generation reads the server's suitcase, so commit first — but after
      // the confirm, so a cancelled replan has no side effect.
      if (_isDirty && !await _commitChanges()) return;
      if (!mounted) return;

      setState(() => _generatingPlan = true);
      try {
        List<Map<String, dynamic>>? days;
        if (_hasTripPlan) {
          days = daysToReplan(_detailState.requireValue.days, _committedIds);
          if (days == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_l10n.noOutfitsNeedReplan)),
              );
            }
            return;
          }
        }
        final detailNotifier = _detailNotifier;
        await TripService().generateTripPlan(
          _tripId,
          days: days,
          alternativesPerDay: 0,
        );
        try {
          await detailNotifier.reloadPlan();
        } on AuthExpiredException {
          rethrow;
        } catch (e) {
          // The plan was generated; Trip Details just shows the old one
          // until it's next re-fetched.
          debugLog('Failed to refresh trip plan after generating: $e');
        }
        if (!mounted) return;
        Navigator.pop(context);
      } on AuthExpiredException {
        if (mounted) await AuthExpiredHandler.handle(context);
      } catch (e) {
        debugLog('Failed to generate trip plan: $e');
        if (mounted) {
          showErrorDialog(context, message: _l10n.failedToGeneratePlan);
        }
      } finally {
        if (mounted) setState(() => _generatingPlan = false);
      }
    } finally {
      if (mounted) setState(() => _planActionInFlight = false);
    }
  }

  Future<void> _removeGarment(Garment garment) async {
    final id = garment.id;
    if (id == null || _pendingIds.contains(id)) return;

    // Staged only — nothing on the server to delete.
    if (!_committedIds.contains(id)) {
      setState(
        () =>
            _packedGarments = _packedGarments.where((g) => g.id != id).toList(),
      );
      return;
    }

    final previousIndex = _packedGarments.indexWhere((g) => g.id == id);
    setState(() {
      _pendingIds.add(id);
      _packedGarments = _packedGarments.where((g) => g.id != id).toList();
    });

    // Puts back only this garment: other removals or picks may have
    // landed while the request was in flight.
    void rollBack() {
      if (_packedGarments.any((g) => g.id == id)) return;
      _packedGarments = [..._packedGarments]
        ..insert(math.min(previousIndex, _packedGarments.length), garment);
    }

    try {
      final detailNotifier = _detailNotifier;
      await TripService().removeSuitcaseItem(_tripId, garmentId: id);
      detailNotifier.removeSuitcaseGarment(id);
      if (mounted) setState(() => _committedIds.remove(id));
    } on AuthExpiredException {
      if (!mounted) return;
      setState(rollBack);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (mounted) setState(rollBack);
      debugLog('Failed to remove suitcase item: $e');
      if (mounted) {
        showErrorDialog(context, message: _l10n.failedToRemoveItem);
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(id));
    }
  }

  AppToolBar _buildAppBar(List<Garment> closetGarments) {
    return AppToolBar(
      title: _l10n.suitcaseLabel,
      onBack: _leaveWithCommit,
      actions: [
        ActionDiscButton(
          icon: Image.asset(
            'assets/images/plus.png',
            height: ActionDisc.iconSize,
          ),
          // Packing before the suitcase has loaded would be overwritten
          // by the load.
          onPressed: _loading ? null : () => _handleAddGarment(closetGarments),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return BottomActionButton(
      label: _hasTripPlan ? _l10n.replanTripOutfits : _l10n.planTripOutfits,
      onPressed: _showsBottomActionButton ? _generatePlan : null,
      isLoading: _generatingPlan,
      leading: const Icon(Icons.auto_awesome_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only for the "+" picker; the packed list doesn't wait on this.
    final closetGarments = (ref.watch(garmentsProvider).value ?? []).active;
    // For [_hasTripPlan].
    ref.watch(tripDetailProvider(_tripId));

    return PopScope(
      canPop: !_isDirty && !_committing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveWithCommit();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.pageBackground,
            extendBody: true,
            appBar: _buildAppBar(closetGarments),
            bottomNavigationBar: _buildBottomBar(),
            body: _buildBody(closetGarments),
          ),
          if (_committing)
            Positioned.fill(
              child: LoadingOverlay(label: _l10n.updatingSuitcaseEllipsis),
            ),
          if (_generatingPlan)
            Positioned.fill(
              child: LoadingOverlay(label: _l10n.generatingPlanEllipsis),
            ),
        ],
      ),
    );
  }

  /// Hidden until outfits and closet have loaded and some outfit has a
  /// closet garment that isn't packed yet.
  bool _hasOutfitToPack(List<Garment> closetGarments) {
    final outfits = ref.watch(outfitsProvider).value ?? const <Outfit>[];
    final closetIds = _indexGarmentsById(closetGarments).keys.toSet();
    final packedIds = _packedIds;
    return outfits.any(
      (o) => o.garmentIds.any(
        (id) => closetIds.contains(id) && !packedIds.contains(id),
      ),
    );
  }

  Widget _buildBody(List<Garment> closetGarments) {
    if (_loading) return const Center(child: AppSpinner());
    final addFromOutfitCard = !_hasOutfitToPack(closetGarments)
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.sectionSpacing),
            child: AppListCard(
              title: _l10n.addFromOutfit,
              leading: const Icon(Icons.style_outlined, color: AppColors.icon),
              showArrow: true,
              onTap: _addFromOutfit,
              child: Text(
                _l10n.addFromOutfitHint,
                style: AppTextStyle.regular12.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
    return RefreshIndicator(
      onRefresh: () => _loadPackedItems(reload: true),
      child: _packedGarments.isEmpty
          ? _buildEmptyPackingState(closetGarments, addFromOutfitCard)
          : CustomScrollView(
              slivers: [
                if (addFromOutfitCard != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: addFromOutfitCard),
                  ),
                Builder(
                  builder: (bodyContext) => SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      addFromOutfitCard == null ? 16 : 0,
                      16,
                      _showsBottomActionButton
                          ? BottomActionButton.scrollClearance(bodyContext)
                          : 16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        for (final category in _categoryOrder)
                          ..._buildCategorySection(
                            category,
                            _packedGarments
                                .where((g) => g.category == category)
                                .toList(),
                          ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyPackingState(
    List<Garment> closetGarments,
    Widget? addFromOutfitCard,
  ) {
    return EmptyStatePlaceholder(
      icon: Icons.luggage_outlined,
      title: _l10n.startPackingTripTitle,
      message: _l10n.startPackingTripHint,
      actionLabel: _l10n.addGarmentsButton,
      onAction: () => _handleAddGarment(closetGarments),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      fillAvailableSpace: true,
      pinnedTop: addFromOutfitCard == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: addFromOutfitCard,
            ),
    );
  }

  Map<int, Garment> _indexGarmentsById(List<Garment> garments) {
    return {
      for (final g in garments)
        if (g.id != null) g.id!: g,
    };
  }

  List<Widget> _buildCategorySection(
    GarmentCategory category,
    List<Garment> garments,
  ) {
    if (garments.isEmpty) return const [];
    return [
      SectionTitle(category.localizedLabel(context)),
      const SizedBox(height: AppDimens.cardHeaderGap),
      GarmentGrid(
        scrollable: false,
        padding: EdgeInsets.zero,
        itemCount: garments.length,
        itemBuilder: (context, i) => _buildGarmentCard(garments[i]),
      ),
      const SizedBox(height: AppDimens.sectionSpacing),
    ];
  }

  Widget _buildGarmentCard(Garment g) {
    return RemovableCard(
      group: _deleteGroup,
      onDelete: () => _removeGarment(g),
      child: GarmentCard(garment: g, showSelectionIndicator: false),
    );
  }
}
