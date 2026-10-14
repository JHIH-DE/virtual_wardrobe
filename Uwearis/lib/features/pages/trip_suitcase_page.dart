import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
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
  // The staged/visible list. Add-picker changes land here without hitting
  // the server; per-card removals still commit immediately (they carry their
  // own confirm). [_committedIds] tracks what the server actually holds.
  List<Garment> _packedGarments = [];
  Set<int> _committedIds = {};
  // Snapshot of [_committedIds] taken once, right after the initial load —
  // unlike [_committedIds] (which moves as changes land), this never
  // changes again, so [_garmentsChangedSinceOpen] has a fixed baseline to
  // compare "what's packed right now" against.
  Set<int> _initialPackedIds = {};
  bool _committing = false;
  final Set<int> _pendingIds = {};
  final _deleteGroup = RemovableCardGroup();

  // Whole-trip plan generation — moved here from Trip Details, since packing
  // the suitcase is the step right before it and the two used to require
  // bouncing between pages.
  bool _generatingPlan = false;
  // Guards the whole action (including the commit-staged-changes step and
  // the regenerate confirm dialog), not just the AI call itself — see
  // CLAUDE.md "Guarding costly / mutating actions against double-invocation".
  bool _planActionInFlight = false;

  Set<int> get _packedIds => {
    for (final g in _packedGarments)
      if (g.id != null) g.id!,
  };

  /// There are staged add-picker changes not yet pushed to the server.
  bool get _isDirty => !setEquals(_packedIds, _committedIds);

  /// The packed suitcase differs from what it was when this page was
  /// opened — via the "+" picker ([TripGarmentSelectionPage]), a direct
  /// per-card removal, or both. Gates "Replan Trip Outfits": once a plan
  /// already exists, replanning it is only useful once something has
  /// actually changed since — see [_showsBottomActionButton].
  bool get _garmentsChangedSinceOpen =>
      !setEquals(_packedIds, _initialPackedIds);

  int get _tripId => int.parse(widget.trip.id);

  AsyncValue<TripDetail> get _detailState =>
      ref.read(tripDetailProvider(_tripId));

  bool get _hasCachedDetail => _detailState.hasValue && !_detailState.hasError;

  TripDetailNotifier get _detailNotifier =>
      ref.read(tripDetailProvider(_tripId).notifier);

  /// Whether this trip already has a generated plan — flips the bottom
  /// button's label between "Plan Trip Outfits" (first time) and "Replan
  /// Trip Outfits" (a plan already exists — see [_generatePlan]'s doc for
  /// what that does differently).
  bool get _hasTripPlan => _detailState.value?.hasTripPlan ?? false;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Mirrors the backend's own minimum-suitcase rule for `/generate`
  /// (`DayPlanGenerator.generate_days_payload` in the backend repo — a top
  /// *and* a bottom, or a one-piece, plus shoes), so the bottom button
  /// doesn't go live for a suitcase the backend would immediately reject
  /// with `SUITCASE_INCOMPLETE`. UX guidance only, kept in sync with that
  /// rule — the backend call remains the authoritative check.
  bool _hasViableSuitcase(List<Garment> suitcase) {
    final categories = suitcase.map((g) => g.category).toSet();
    final hasTopAndBottom =
        categories.contains(GarmentCategory.top) &&
        categories.contains(GarmentCategory.bottom);
    final hasOnePiece = categories.contains(GarmentCategory.onePiece);
    final hasShoes = categories.contains(GarmentCategory.shoes);
    return (hasTopAndBottom || hasOnePiece) && hasShoes;
  }

  /// Checked against [_packedGarments] (the staged/visible list), not just
  /// [_committedIds] — a just-added, not-yet-committed piece should already
  /// count, since [_generatePlan] commits any staged changes before it asks
  /// the backend to plan.
  bool get _isSuitcaseViable => _hasViableSuitcase(_packedGarments);

  /// A first plan ("Plan Trip Outfits") always makes sense once the
  /// suitcase is viable — but once a plan already exists, replanning it
  /// ("Replan Trip Outfits") is only worth surfacing once something has
  /// actually changed since this page opened.
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
      // Also keeps the detail provider listened to while a first load
      // below may still be retrying.
      _watchAuthExpiry(tripDetailProvider(_tripId));
      ref.read(garmentsProvider.notifier).refreshIfNeeded();
    });
    // Trip Details has normally loaded the suitcase already — render it
    // at once instead of fetching it again.
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

  /// Without [reload], waits on [tripDetailProvider]'s own first load (this
  /// page was reached before Trip Details had loaded it); with it — pull to
  /// refresh — re-fetches the suitcase.
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

    // Stage the change — the "Confirm" bottom button (or leaving the page)
    // pushes it to the server. See [_commitChanges].
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

  /// Lets the user pick a saved outfit's version, then stages whichever of
  /// its garments are still in the closet and not packed yet — the same way
  /// the "+" picker stages its picks (committed on Confirm / leaving).
  Future<void> _addFromOutfit() async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
    if (!mounted) return;
    final outfit = await Navigator.push<Outfit>(
      context,
      MaterialPageRoute(builder: (_) => const TripOutfitSelectionPage()),
    );
    if (outfit == null || !mounted) return;

    // .active: a soft-deleted garment can't be packed.
    final closetById = _indexGarmentsById(
      (ref.read(garmentsProvider).value ?? const <Garment>[]).active,
    );
    final packedIds = _packedIds;
    final newGarments = [
      for (final id in outfit.garmentIds.toSet())
        if (!packedIds.contains(id) && closetById[id] != null) closetById[id]!,
    ];

    if (newGarments.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.noNewItemsFromOutfit)));
      return;
    }
    setState(() => _packedGarments = [..._packedGarments, ...newGarments]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n.addedItemsFromOutfitCount(newGarments.length)),
      ),
    );
  }

  /// Pushes the staged difference between [_packedIds] and [_committedIds] to
  /// the server. Returns whether it succeeded (a failing commit keeps the
  /// user on the page with the changes still staged).
  Future<bool> _commitChanges() async {
    if (_committing || !_isDirty) return true;
    final toAdd = _packedIds.difference(_committedIds);
    final toRemove = _committedIds.difference(_packedIds);
    final committed = List.of(_packedGarments);
    final detailNotifier = _detailNotifier;
    setState(() => _committing = true);
    try {
      for (final id in toAdd) {
        await TripService().addSuitcaseItem(_tripId, garmentId: id);
      }
      for (final id in toRemove) {
        await TripService().removeSuitcaseItem(_tripId, garmentId: id);
      }
      detailNotifier.setSuitcase(committed);
      if (mounted) setState(() => _committedIds = {..._packedIds});
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
      if (mounted) setState(() => _committing = false);
    }
  }

  /// Back-arrow / system-back handler: silently flush any staged add-picker
  /// changes before leaving (there's no "wrong" suitcase to discard), then
  /// pop. A failed commit keeps the user here with the changes still staged.
  Future<void> _leaveWithCommit() async {
    if (_committing) return;
    if (_isDirty && !await _commitChanges()) return;
    if (mounted) Navigator.pop(context);
  }

  /// First time ("Plan Trip Outfits"): builds an outfit for every day from
  /// whatever's currently packed — no existing plan to protect, so this
  /// just generates everything.
  ///
  /// Once a plan already exists ("Replan Trip Outfits" — this page's entry
  /// point for "I changed the suitcase, replan around it"; TripDetailsPage's
  /// Daily Outfit Plan refresh icon is the other, for "I didn't touch the
  /// suitcase but want a different result"), confirms first via the shared
  /// [showReplanConfirmDialog], then commits any staged suitcase changes,
  /// then reads the day-by-day plan from [tripDetailProvider] to decide
  /// which days actually need regenerating via the shared
  /// [daysToReplan] (both entry points build the request the same way —
  /// see its own doc for the underlying [TripDayOutfit.needsReplan] policy).
  /// A day the user manually adjusted or already rendered is left untouched
  /// unless it now references a garment no longer packed. If nothing needs
  /// it, `generate` isn't called at all.
  ///
  /// The confirm dialog runs *before* [_commitChanges] (not after) so a
  /// Cancel here never leaves staged suitcase edits pushed to the server —
  /// only a confirmed replan is allowed to have any side effect at all.
  /// On success, re-fetches the plan into [tripDetailProvider] (still under
  /// the generating overlay) and pops back to Trip Details, which watches
  /// it — so the result is already there on arrival.
  Future<void> _generatePlan() async {
    if (_planActionInFlight) return;
    setState(() => _planActionInFlight = true);
    try {
      if (_hasTripPlan) {
        final confirmed = await showReplanConfirmDialog(context);
        if (!confirmed || !mounted) return;
      }

      // Generation reads the suitcase from the server, so any staged
      // add-picker changes must land first — after the confirm above, so a
      // cancelled replan never pushes a suitcase edit as a side effect.
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

    // Still just staged (added via the picker, not committed) — drop it
    // locally, nothing on the server to delete.
    if (!_committedIds.contains(id)) {
      setState(
        () =>
            _packedGarments = _packedGarments.where((g) => g.id != id).toList(),
      );
      return;
    }

    final previousGarments = _packedGarments;
    setState(() {
      _pendingIds.add(id);
      _packedGarments = _packedGarments.where((g) => g.id != id).toList();
    });

    try {
      final detailNotifier = _detailNotifier;
      final affected = await TripService().removeSuitcaseItem(
        _tripId,
        garmentId: id,
      );
      detailNotifier.removeSuitcaseGarment(id);
      if (mounted) setState(() => _committedIds.remove(id));
      // Purely informational — see TripAffectedOption's doc. No Fix/Replan
      // offered yet; the removal above has already succeeded either way.
      if (affected.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.suitcaseItemStillUsedCount(affected.length)),
          ),
        );
      }
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => _packedGarments = previousGarments);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (mounted) setState(() => _packedGarments = previousGarments);
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

  /// The whole-trip "Plan"/"Replan Trip Outfits" action — see [_generatePlan].
  /// Always built (never null): every trip wants this eventually, it's just
  /// hidden ([_showsBottomActionButton], via BottomActionButton's own
  /// unavailable-state handling) while the suitcase can't build a complete
  /// outfit yet or another suitcase action is in flight.
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
    // Only needed for the "Add" picker's full closet — the packed list
    // itself now renders straight from _packedGarments (embedded fields
    // from the trip response), so it isn't gated on this loading/erroring.
    // .active: a soft-deleted garment can't be packed into a new trip item.
    final closetGarments = (ref.watch(garmentsProvider).value ?? []).active;
    // For [_hasTripPlan] (the bottom button's label).
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

  Widget _buildBody(List<Garment> closetGarments) {
    // A brief page read — an in-place spinner rather than a full-screen
    // LoadingOverlay, which would also blur the toolbar's back button.
    if (_loading) return const Center(child: AppSpinner());
    // Packs every garment of a saved outfit in one go — the same entry
    // point style as Trip Details' Suitcase card. Shown above both the
    // packed list and the empty state.
    final addFromOutfitCard = Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionSpacing),
      child: AppListCard(
        title: _l10n.addFromOutfit,
        leading: const Icon(Icons.style_outlined, color: AppColors.icon),
        showArrow: true,
        onTap: _addFromOutfit,
        child: Text(
          _l10n.addFromOutfitHint,
          style: AppTextStyle.regular14.copyWith(
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: addFromOutfitCard),
                ),
                SliverPadding(
                  // Bottom clearance lives here, inside the scrollable
                  // content, rather than as a sibling below it — so the
                  // list keeps extending under the floating button
                  // (extendBody: true) instead of leaving a flat blank
                  // strip painted in the page background.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    _showsBottomActionButton
                        ? AppDimens.bottomActionBtnClearance
                        : 16,
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
              ],
            ),
    );
  }

  /// Empty-suitcase state — the shared icon+title+hint+action treatment
  /// (see [EmptyStatePlaceholder]), same mechanism Closet/Outfits/Trips'
  /// empty tabs use ([fillAvailableSpace]). [pinnedTop] carries
  /// [addFromOutfitCard] above the centered content.
  Widget _buildEmptyPackingState(
    List<Garment> closetGarments,
    Widget addFromOutfitCard,
  ) {
    return EmptyStatePlaceholder(
      icon: Icons.luggage_outlined,
      title: _l10n.startPackingTripTitle,
      message: _l10n.startPackingTripHint,
      actionLabel: _l10n.addGarmentsButton,
      onAction: () => _handleAddGarment(closetGarments),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      fillAvailableSpace: true,
      pinnedTop: Padding(
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
