import 'dart:async';
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
import '../../data/trip_outfit.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/trip_outfit_error_text.dart';
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
  // Covers the commit too, not just the AI call.
  bool _planActionInFlight = false;
  // Covers the version picker too; [_addingOutfit] drives the overlay once
  // the picker has returned.
  bool _addOutfitInFlight = false;
  bool _addingOutfit = false;

  Set<int> get _packedIds => {
    for (final g in _packedGarments)
      if (g.id != null) g.id!,
  };

  bool get _isDirty => !setEquals(_packedIds, _committedIds);

  bool get _garmentsChangedSinceOpen =>
      !setEquals(_packedIds, _initialPackedIds);

  int get _tripId => int.parse(widget.trip.id);

  AsyncValue<TripOutfitCollection> get _detailState =>
      ref.read(tripDetailProvider(_tripId));

  bool get _hasCachedDetail => _detailState.hasValue && !_detailState.hasError;

  TripDetailNotifier get _detailNotifier =>
      ref.read(tripDetailProvider(_tripId).notifier);

  bool get _hasOutfits => _detailState.value?.outfits.isNotEmpty ?? false;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Staged pieces count: [_generatePlan] commits them before planning.
  bool get _isSuitcaseViable => isViableSuitcase(_packedGarments);

  /// With outfits already planned, a suitcase change offers more outfits
  /// that use it — existing ones are only re-checked for missing garments.
  bool get _showsBottomActionButton =>
      !_generatingPlan &&
      !_planActionInFlight &&
      !_committing &&
      !_addOutfitInFlight &&
      _isSuitcaseViable &&
      (!_hasOutfits || _garmentsChangedSinceOpen);

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

  /// Adds the whole saved outfit to the trip and packs its missing garments
  /// in one backend transaction — also when everything is packed already.
  /// Staged picks are committed first so the server's suitcase matches what
  /// the user sees before the outfit's garments are merged in.
  Future<void> _addFromOutfit() async {
    if (_addOutfitInFlight) return;
    setState(() => _addOutfitInFlight = true);
    try {
      await ref.read(garmentsProvider.notifier).refreshIfNeeded();
      if (!mounted) return;
      final outfit = await Navigator.push<Outfit>(
        context,
        MaterialPageRoute(
          builder: (_) => TripOutfitSelectionPage(
            packedGarmentIds: _packedIds,
            addedOutfitIds:
                _detailState.value?.addedSourceOutfitIds ?? const {},
          ),
        ),
      );
      if (outfit == null || !mounted) return;
      if (_isDirty && !await _commitChanges()) return;
      if (!mounted) return;

      setState(() => _addingOutfit = true);
      final packedBefore = _packedIds;
      final detailNotifier = _detailNotifier;
      final collection = await TripService().addTripOutfitFromSaved(
        _tripId,
        outfitId: outfit.id,
      );
      detailNotifier.setCollection(collection);
      if (!mounted) return;
      final packedCount = collection.suitcaseIds
          .difference(packedBefore)
          .length;
      setState(() {
        _packedGarments = List.of(collection.suitcase);
        _committedIds = collection.suitcaseIds;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            packedCount > 0
                ? _l10n.addedOutfitToTripPacked(packedCount)
                : _l10n.addedOutfitToTrip,
          ),
        ),
      );
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Failed to add outfit to trip: $e');
      if (mounted) {
        showErrorDialog(
          context,
          message: tripOutfitErrorMessage(
            _l10n,
            e,
            fallback: _l10n.failedToAddTripOutfit,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _addOutfitInFlight = false;
          _addingOutfit = false;
        });
      }
    }
  }

  /// Saved-outfit candidates depend on the suitcase; a failure just leaves
  /// the cached ones until the next load.
  Future<void> _reloadCollectionQuietly() async {
    try {
      await _detailNotifier.reloadTripDetail();
    } catch (e) {
      debugLog('Failed to reload trip outfits: $e');
    }
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
      if (toAdd.isNotEmpty) {
        await TripService().addSuitcaseItems(
          _tripId,
          garmentIds: toAdd.toList(),
        );
        committedNow.addAll(toAdd);
        detailNotifier.addSuitcaseGarments([for (final id in toAdd) ?byId[id]]);
      }
      for (final id in toRemove) {
        await TripService().removeSuitcaseItem(_tripId, garmentId: id);
        committedNow.remove(id);
        detailNotifier.removeSuitcaseGarment(id);
      }
      detailNotifier.setSuitcase(committed);
      unawaited(_reloadCollectionQuietly());
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

  /// Plan (no outfits yet) or Find More (after a suitcase change). Never
  /// replaces existing outfits, so there's no confirm. The response is the
  /// whole collection, applied before popping so Trip Details shows it.
  Future<void> _generatePlan() async {
    if (_planActionInFlight) return;
    setState(() => _planActionInFlight = true);
    try {
      // Generation reads the server's suitcase, so commit first.
      if (_isDirty && !await _commitChanges()) return;
      if (!mounted) return;

      setState(() => _generatingPlan = true);
      try {
        final detailNotifier = _detailNotifier;
        final messenger = ScaffoldMessenger.of(context);
        final result = await TripService().generateTripOutfits(
          _tripId,
          mode: _hasOutfits
              ? TripOutfitGenerateMode.more
              : TripOutfitGenerateMode.plan,
        );
        detailNotifier.setCollection(result.collection);
        // Shown over Trip Details after the pop.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.generatedCount > 0
                  ? _l10n.addedTripOutfitsCount(result.generatedCount)
                  : result.collection.savedCandidates.isNotEmpty
                  ? _l10n.savedCandidatesAvailable(
                      result.collection.savedCandidates.length,
                    )
                  : _l10n.noMoreTripOutfitCombinations,
            ),
          ),
        );
        if (!mounted) return;
        Navigator.pop(context);
      } on AuthExpiredException {
        if (mounted) await AuthExpiredHandler.handle(context);
      } catch (e) {
        debugLog('Failed to generate trip outfits: $e');
        if (mounted) {
          showErrorDialog(
            context,
            message: tripOutfitErrorMessage(
              _l10n,
              e,
              fallback: _l10n.failedToGeneratePlan,
            ),
          );
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
      unawaited(_reloadCollectionQuietly());
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
      label: _hasOutfits ? _l10n.findMoreOutfits : _l10n.planTripOutfits,
      onPressed: _showsBottomActionButton ? _generatePlan : null,
      isLoading: _generatingPlan,
      leading: const Icon(Icons.auto_awesome_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only for the "+" picker; the packed list doesn't wait on this.
    final closetGarments = (ref.watch(garmentsProvider).value ?? []).active;
    // For [_hasOutfits] and the saved-outfit count.
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
          if (_committing || _addingOutfit)
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

  /// Hidden until the user's outfits have loaded and there is one; an
  /// outfit whose garments are all packed can still be added to the trip.
  bool get _hasSavedOutfits =>
      (ref.watch(outfitsProvider).value ?? const <Outfit>[]).isNotEmpty;

  Widget _buildBody(List<Garment> closetGarments) {
    if (_loading) return const Center(child: AppSpinner());
    final savedInTrip = _detailState.value?.savedOutfitCount ?? 0;
    final addFromOutfitCard = !_hasSavedOutfits
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.sectionSpacing),
            child: AppListCard(
              leading: const Icon(Icons.style_outlined, color: AppColors.icon),
              showArrow: true,
              status: savedInTrip > 0
                  ? _l10n.savedOutfitsInTripCount(savedInTrip)
                  : null,
              onTap: _addOutfitInFlight ? null : _addFromOutfit,
              child: Text(_l10n.addFromOutfit, style: AppTextStyle.bold16),
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
