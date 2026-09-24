import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/trip_suggestion_provider.dart';
import '../../core/providers/trips_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/route_observer.dart';
import '../../core/utils/signed_url.dart';
import '../../data/garment.dart';
import '../../data/trip.dart';
import '../../data/trip_plan.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/edge_fade_scrim.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_image.dart';
import '../widgets/trip/replan_confirm_dialog.dart';
import '../widgets/trip/today_outfit_idea.dart';
import '../widgets/trip/trip_day_card.dart';
import '../widgets/trip/trip_legs_editor.dart';
import 'outfit_edit_page.dart';
import 'trip_suitcase_page.dart';

/// Actions in [TripDetailsPage]'s app bar "⋮" menu — moved here from
/// [TripCard] (the Trips-tab list item) so a trip's own metadata edits live
/// on its detail page instead of duplicated across every card that links
/// to it.
enum _TripMenuAction { editName, editLegs, delete }

class TripDetailsPage extends ConsumerStatefulWidget {
  final Trip trip;
  final TripPlan initialData;

  const TripDetailsPage({
    super.key,
    required this.trip,
    required this.initialData,
  });

  /// Fetches everything [TripDetailsPage] needs up front, so the page can be
  /// pushed only once loading is complete (no in-page spinner on open).
  ///
  /// Uses `getTripPlan` (`GET /{trip_id}/plan`), not `getTrip` — the latter
  /// only reports days with an already-rendered outfit, so a plan that's
  /// been generated (`POST /generate`) but never rendered into an image
  /// would come back looking exactly like no plan exists at all. `/plan`'s
  /// `days[].options[]` covers both cases and is self-contained (each
  /// option's items embed their own image/name/category — no closet lookup).
  static Future<TripPlan> preload(Trip trip) async {
    try {
      return await TripService().getTripPlan(int.parse(trip.id));
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
      debugLog('Failed to load trip outfits: $e');
      return const TripPlan();
    }
  }

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage>
    with RouteAware {
  // TripDayCard's own width plus the gap between cards — used to compute
  // how far to scroll the day selector to bring a tapped card into view.
  static const double _dayCardWidth = 95;
  static const double _dayCardGap = 8;
  // Snug around TripDayCard's tallest state (date row + temperature line);
  // the cards stretch to this so temp / no-temp days stay the same height.
  static const double _dayCardHeight = 78;

  int _selectedDayIndex = 0;
  final ScrollController _dayScrollController = ScrollController();

  // Mutable local copy — the app bar's edit menu (name/destinations/
  // activities) needs to update what's on screen immediately, and
  // [widget.trip] is otherwise a fixed snapshot from whoever pushed this
  // page. Kept in sync with [tripsProvider] by [_updateTrip].
  late Trip _trip = widget.trip;

  late List<TripDayOutfit> _dayOutfits = widget.initialData.days;
  late Set<int> _suitcaseIds = widget.initialData.suitcaseIds;

  // Display-only — feeds the "Recommended N · Selected M" summary on the
  // Suitcase card (see [_buildSuitcaseSection]). Packing guidance, never a
  // plan-generation gate — that lives on TripSuitcasePage now.
  int? _recommendedTotal;
  bool _generatingOutfit = false;
  bool _loadingEditor = false;
  // Re-entrancy guard for the *whole* generate/regenerate-day-outfit flow,
  // including the regenerate confirm dialog — see [_generateSelectedDayOutfit].
  bool _dayOutfitActionInFlight = false;
  // Same shape as [_dayOutfitActionInFlight], for the whole-trip Replan
  // triggered from the Daily Outfit Plan refresh icon — see [_replanPlan].
  bool _replanActionInFlight = false;
  bool _replanningPlan = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  TripDayOutfit? get _currentDayOutfit => _selectedDayIndex < _dayOutfits.length
      ? _dayOutfits[_selectedDayIndex]
      : null;

  List<Garment> get _todayGarments => _currentDayOutfit?.garments ?? const [];

  /// True if any of today's outfit garments have since been removed from
  /// the trip's suitcase — e.g. the user unpacked something after Uwearis (or
  /// the user themself) already assigned it to this day.
  bool get _hasMissingSuitcaseItems =>
      _todayGarments.any((g) => g.id != null && !_suitcaseIds.contains(g.id));

  /// A plan has been generated if any day carries an option at all — mirrors
  /// the check [TripSuitcasePage] uses (via [_openSuitcase]'s
  /// `initialHasTripPlan`) to decide whether its own generate button should
  /// confirm before overwriting.
  bool get _hasTripPlan => _dayOutfits.any((d) => d.optionId != null);

  /// Whether the *selected* day specifically has an option assigned — unlike
  /// [_hasTripPlan] (any day at all), this gates [_buildOutfitSection] and
  /// [_buildWardrobeSection]'s "let Uwearis plan" CTA for the day currently
  /// on screen (e.g. a leg added after the plan was first generated still
  /// has no option of its own even though other days do).
  bool get _selectedDayHasOption => _currentDayOutfit?.optionId != null;

  /// Whether today's assigned garments cover Top, Bottom, and Shoes — a
  /// one-piece counts for both Top and Bottom, mirroring AddOutfitPage's own
  /// core-completeness rule. Gates the "Generate Outfit" button's *enabled*
  /// state ([_buildOutfitSection]): the button itself always shows once a
  /// day has an option and no render yet, but generating from an incomplete
  /// core selection isn't offered.
  bool get _hasCoreOutfit {
    bool hasCategory(GarmentCategory c) =>
        _todayGarments.any((g) => g.category == c);
    final hasOnePiece = hasCategory(GarmentCategory.onePiece);
    return (hasOnePiece || hasCategory(GarmentCategory.top)) &&
        (hasOnePiece || hasCategory(GarmentCategory.bottom)) &&
        hasCategory(GarmentCategory.shoes);
  }

  @override
  void initState() {
    super.initState();
    _loadPackingAnalysis();
    // preload() fetched fresh garment image URLs, but if this page instance
    // stays open long enough for them to expire (e.g. backgrounded, or the
    // trip was preloaded a while before the user actually opened it), there
    // was previously no way to recover — the day outfits were immutable.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureFreshDayGarments(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribes (re-subscribing is a harmless no-op) so [didPopNext] fires
    // whenever a page pushed on top of this one is popped back to it — see
    // its doc comment for why this page can't rely on knowing how that push
    // happened.
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _dayScrollController.dispose();
    super.dispose();
  }

  /// Set right before pushing the day outfit editor ([_openDayOutfitEditor])
  /// and consumed by [didPopNext] the instant that page pops back — skips
  /// *that one* [_refreshTripPlan] call. [_openDayOutfitEditor] immediately
  /// follows the pop with its own authoritative update
  /// ([TripService.updateOptionItems]); [didPopNext]'s `GET /plan` used to
  /// race that PATCH and, whenever the GET won, overwrite the just-applied
  /// edit with the pre-edit plan — the edit then only "stuck" after leaving
  /// and re-entering the page. [_fetchSuitcaseGarments] isn't affected: it
  /// only touches [_suitcaseIds], which this flow doesn't change.
  bool _skipPlanRefreshOnNextPop = false;

  /// Fires when a page pushed on top of this one is popped and this page is
  /// visible again — including [TripSuitcasePage], which may have changed
  /// the suitcase and/or (re)generated the trip's plan (that action lives
  /// there now — see [_refreshTripPlan]). This is the single place
  /// [_suitcaseIds]/[_dayOutfits] get refreshed on return, deliberately not
  /// tied to *how* the Suitcase page was reached: [_openSuitcase] pushes it
  /// directly, but right after trip creation (`TripsPage.handleCreateTrip`)
  /// it's pushed on top of this page from outside — before this hook
  /// existed, popping back from that first just-created visit left
  /// [_suitcaseIds] at its stale (empty, pre-pack) preload snapshot. See
  /// [_skipPlanRefreshOnNextPop] for the one case where this refetch is
  /// skipped instead.
  @override
  void didPopNext() {
    _fetchSuitcaseGarments();
    if (_skipPlanRefreshOnNextPop) {
      _skipPlanRefreshOnNextPop = false;
    } else {
      _refreshTripPlan();
    }
  }

  bool get _hasStaleGarmentImages => _dayOutfits.any(
    (day) => anySignedUrlExpired(day.garments.map((g) => g.imageUrl)),
  );

  /// Day outfit garments are resolved against the closet (see
  /// [TripPlan.fromRenderedResponse]), so refreshing a stale image URL means
  /// re-fetching both the trip and the closet.
  Future<void> _ensureFreshDayGarments() async {
    if (!_hasStaleGarmentImages) return;
    try {
      final tripData = await TripService().getTrip(int.parse(_trip.id));
      final closetGarments = await GarmentService().getGarments();
      final dayOutfits = TripPlan.fromRenderedResponse(
        tripData,
        closetGarments,
      ).days;
      if (!mounted) return;
      setState(() => _dayOutfits = dayOutfits);
    } catch (_) {
      // Leave the existing URLs; GarmentImage's errorWidget covers the
      // fallback if they've truly expired.
    }
  }

  /// Loads the trip's packing analysis for [_recommendedTotal] — the
  /// packing-gate / "Generate Trip Plan" threshold. The advice text itself
  /// (`analysis.overallAdvice`) now renders on [TripSuitcasePage], which
  /// watches the same cached [tripSuggestionProvider] directly rather than
  /// this page passing the text through.
  Future<void> _loadPackingAnalysis() async {
    try {
      // Shared with the suitcase page/garment picker (see
      // tripSuggestionProvider) so opening either doesn't re-request the
      // same analysis.
      final analysis = await ref.read(
        tripSuggestionProvider(int.parse(_trip.id)).future,
      );
      if (mounted) {
        setState(() {
          _recommendedTotal = analysis.categories.isEmpty
              ? null
              : analysis.recommendedTotal;
        });
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      if (!mounted) return;
      debugLog('Failed to analyze trip plan: $e');
    }
  }

  /// Fetches the trip's current suitcase, resolved to full [Garment]
  /// objects straight from each item's own embedded `image_url`/`category`/
  /// `name` fields (`TripSuitcaseItemResponse`) — no closet fetch needed —
  /// and syncs [_suitcaseIds] along the way. Returns null (after showing an
  /// error) if the fetch fails.
  Future<List<Garment>?> _fetchSuitcaseGarments() async {
    try {
      final tripData = await TripService().getTrip(int.parse(_trip.id));
      final rawSuitcaseItems = (tripData['suitcase_items'] as List?) ?? [];
      final suitcase = rawSuitcaseItems
          .whereType<Map<String, dynamic>>()
          .map(Garment.fromTripItemJson)
          .toList();
      if (mounted) {
        setState(
          () => _suitcaseIds = parseSuitcaseItemIds(tripData['suitcase_items']),
        );
      }
      return suitcase;
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return null;
    } catch (e) {
      debugLog('Failed to load suitcase: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateDayOutfit)));
      }
      return null;
    }
  }

  /// Re-fetches this trip's plan so a generation/update triggered from
  /// [TripSuitcasePage] (which owns that action now) shows up here the
  /// moment the user comes back — called from [didPopNext] (see
  /// [_skipPlanRefreshOnNextPop] for the one case that skips it). Doesn't use
  /// the [preload] static helper: that swallows errors into an empty
  /// [TripPlan] (fine for the initial load before this page even exists),
  /// which would wipe out a perfectly good [_dayOutfits] here on a
  /// transient failure — a plain try/catch that changes nothing on error
  /// matches [_ensureFreshDayGarments] instead.
  Future<void> _refreshTripPlan() async {
    try {
      final plan = await TripService().getTripPlan(int.parse(_trip.id));
      if (!mounted) return;
      setState(() {
        _dayOutfits = plan.days;
        _selectedDayIndex = _dayOutfits.isEmpty
            ? 0
            : _selectedDayIndex.clamp(0, _dayOutfits.length - 1);
      });
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Failed to refresh trip plan: $e');
    }
  }

  /// This page's own Replan entry point — the Daily Outfit Plan title's
  /// refresh icon (see [_buildDayPlanCard]). Unlike TripSuitcasePage's
  /// bottom button (which only shows once the suitcase has changed since it
  /// was opened), this doesn't require the suitcase to have changed at all:
  /// it's for "I didn't touch the suitcase, I just don't like what Uwearis
  /// picked." Shares the same confirm dialog ([showReplanConfirmDialog]) and
  /// the same day-selection policy ([daysToReplan] /
  /// [TripDayOutfit.needsReplan]) as TripSuitcasePage, straight off this
  /// page's own already-loaded [_dayOutfits]/[_suitcaseIds] — no extra
  /// `getTripPlan` round trip needed, unlike Suitcase (which doesn't hold
  /// day-level data at all). On success this refreshes in place
  /// ([_refreshTripPlan]) rather than popping anywhere.
  Future<void> _replanPlan() async {
    if (_replanActionInFlight || _dayOutfitActionInFlight) return;
    setState(() => _replanActionInFlight = true);
    try {
      final confirmed = await showReplanConfirmDialog(context);
      if (!confirmed || !mounted) return;

      final days = daysToReplan(_dayOutfits, _suitcaseIds);
      if (days == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_l10n.noOutfitsNeedReplan)));
        }
        return;
      }

      setState(() => _replanningPlan = true);
      try {
        await TripService().generateTripPlan(
          int.parse(_trip.id),
          days: days,
          alternativesPerDay: 0,
        );
        if (!mounted) return;
        await _refreshTripPlan();
      } on AuthExpiredException {
        if (mounted) await AuthExpiredHandler.handle(context);
      } catch (e) {
        debugLog('Failed to replan trip: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_l10n.failedToGeneratePlan)));
        }
      } finally {
        if (mounted) setState(() => _replanningPlan = false);
      }
    } finally {
      if (mounted) setState(() => _replanActionInFlight = false);
    }
  }

  // The refetch on return is [didPopNext], not here — see its doc comment.
  Future<void> _openSuitcase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TripSuitcasePage(trip: _trip, initialHasTripPlan: _hasTripPlan),
      ),
    );
  }

  /// Synchronously renders the *currently selected* day's option into a
  /// try-on image — reachable from the outfit card's "Generate"/"Regenerate
  /// Outfit" empty-state button (see [_buildOutfitSection]'s `onGenerate`)
  /// or the corner regenerate badge on the image itself once one already
  /// exists (`onRegenerate`). Branches on whether this option already has an
  /// `outfit_id` —
  /// the backend now splits first render ([TripService.generateOptionOutfit],
  /// 409s if already rendered) from re-rendering an existing one
  /// ([TripService.regenerateOptionOutfit], 400s if never rendered) into two
  /// endpoints, so calling the wrong one for the option's current state
  /// fails outright. Captures the day index up front and re-checks it still
  /// points at the same option before applying the result, so a slow
  /// request landing after the user has switched days (or edited this same
  /// day's garments again) can't clobber a different day's state.
  Future<void> _generateSelectedDayOutfit() async {
    // Guards the whole flow (the regenerate confirm dialog included), not
    // just the AI call — the regenerate path used to be reachable only
    // through a single-shot "⋮" menu item, which couldn't itself re-fire
    // during that dialog's await; now it's a plain always-visible icon
    // button, so this flag has to cover that window too. Distinct from
    // [_generatingOutfit] (the visual loading overlay), which should only
    // show once the AI call itself starts, not over the confirm dialog. See
    // CLAUDE.md "Guarding costly / mutating actions against
    // double-invocation".
    if (_dayOutfitActionInFlight) return;
    setState(() => _dayOutfitActionInFlight = true);
    try {
      final dayIndex = _selectedDayIndex;
      final before = _dayOutfits[dayIndex];
      final optionId = before.optionId;
      if (optionId == null) return;
      final isRegenerate = before.outfitId != null;

      // Regenerating throws away the current render for a fresh *paid* AI
      // one. Confirm first, mirroring OutfitDetailsPage._regenerateImage. A
      // first render ("Generate Outfit") has nothing to discard, so that
      // path skips the prompt.
      if (isRegenerate) {
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
        if (ok != true || !mounted) return;
      }

      setState(() => _generatingOutfit = true);
      try {
        final result = isRegenerate
            ? await TripService().regenerateOptionOutfit(
                int.parse(_trip.id),
                optionId: optionId,
              )
            : await TripService().generateOptionOutfit(
                int.parse(_trip.id),
                optionId: optionId,
              );
        if (!mounted) return;
        final current = dayIndex < _dayOutfits.length
            ? _dayOutfits[dayIndex]
            : null;
        if (current == null || current.optionId != optionId) return;
        setState(() {
          _dayOutfits[dayIndex] = TripDayOutfit(
            date: current.date,
            optionId: optionId,
            garments: current.garments,
            outfitId: result.outfitId,
            resultImageUrl: result.resultImageUrl,
            temperatureMaxC: current.temperatureMaxC,
            temperatureMinC: current.temperatureMinC,
            everHadOutfit: true,
          );
        });
      } on AuthExpiredException {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      } catch (e) {
        debugLog('Failed to generate day outfit: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_l10n.failedToGenerateOutfit)));
        }
      } finally {
        if (mounted) setState(() => _generatingOutfit = false);
      }
    } finally {
      if (mounted) setState(() => _dayOutfitActionInFlight = false);
    }
  }

  /// Lets the user manually swap which suitcase garments make up the
  /// selected day's outfit, via [OutfitEditPage]'s per-category
  /// slot picker. Only reachable once Uwearis has generated a plan (there has
  /// to be an existing option to PATCH).
  Future<void> _openDayOutfitEditor() async {
    final optionId = _currentDayOutfit?.optionId;
    if (optionId == null) return;

    setState(() => _loadingEditor = true);
    final fetched = await _fetchSuitcaseGarments();
    if (mounted) setState(() => _loadingEditor = false);
    if (fetched == null || !mounted) return;
    final suitcaseGarments = fetched;

    final validIds = Set.of(_suitcaseIds);

    // See _skipPlanRefreshOnNextPop's doc comment.
    _skipPlanRefreshOnNextPop = true;
    final result = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitEditPage(
          initialGarments: _todayGarments,
          preloadedGarments: suitcaseGarments,
          validGarmentIds: validIds,
          title: _l10n.editOutfitTitle,
        ),
      ),
    );
    if (result == null || !mounted) return;

    try {
      final newGarments = await TripService().updateOptionItems(
        int.parse(_trip.id),
        optionId: optionId,
        garmentIds: result.toList(),
      );
      if (!mounted) return;
      setState(() {
        // updateOptionItems clears this option's already-tried-on outfit
        // server-side (see its doc comment) — outfitId/resultImageUrl drop
        // to null here to match, rather than keeping the now-stale values
        // around. everHadOutfit stays sticky so the CTA reads "Regenerate"
        // rather than "Generate" once the user does render this slot again.
        _dayOutfits[_selectedDayIndex] = TripDayOutfit(
          date: _currentDayOutfit?.date,
          optionId: optionId,
          temperatureMaxC: _currentDayOutfit?.temperatureMaxC,
          temperatureMinC: _currentDayOutfit?.temperatureMinC,
          garments: newGarments,
          everHadOutfit: _currentDayOutfit?.everHadOutfit ?? false,
        );
      });
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to update day outfit: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateDayOutfit)));
      }
    }
  }

  /// "Fix" action for the missing-items warning: re-adds whatever's
  /// currently in this day's outfit but missing from the suitcase back into
  /// it, rather than making the user go re-pick the outfit.
  Future<void> _fixMissingSuitcaseItems() async {
    final missingIds = _todayGarments
        .where((g) => g.id != null && !_suitcaseIds.contains(g.id))
        .map((g) => g.id!)
        .toList();
    if (missingIds.isEmpty) return;

    try {
      for (final id in missingIds) {
        await TripService().addSuitcaseItem(int.parse(_trip.id), garmentId: id);
      }
      if (!mounted) return;
      setState(() => _suitcaseIds.addAll(missingIds));
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to re-add missing suitcase items: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateSuitcase)));
      }
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _l10n.tripDetailsTitle,
      actions: [
        AppPopupMenu<_TripMenuAction>(
          onSelected: _handleTripMenuAction,
          items: [
            AppPopupMenu.item(
              value: _TripMenuAction.editName,
              icon: Image.asset(
                'assets/images/edit.png',
                width: 20,
                height: 20,
              ),
              label: _l10n.editTripName,
            ),
            AppPopupMenu.item(
              value: _TripMenuAction.editLegs,
              icon: const Icon(
                Icons.map_outlined,
                size: 20,
                color: AppColors.icon,
              ),
              label: _l10n.editDestinations,
            ),
            AppPopupMenu.item(
              value: _TripMenuAction.delete,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.icon,
              ),
              label: _l10n.deleteTrip,
              isDestructive: true,
            ),
          ],
        ),
      ],
    );
  }

  void _handleTripMenuAction(_TripMenuAction action) {
    switch (action) {
      case _TripMenuAction.editName:
        _editTripName();
      case _TripMenuAction.editLegs:
        _editTripLegs();
      case _TripMenuAction.delete:
        _confirmDeleteTrip();
    }
  }

  Future<void> _editTripName() async {
    final result = await showTextInputDialog(
      context,
      title: _l10n.editTripName,
      hint: _l10n.enterTripName,
      initialValue: _trip.name,
    );
    if (result == null) return;
    await _updateTrip(_trip.copyWith(name: result));
  }

  Future<void> _editTripLegs() async {
    final initialLegs = List<TripLeg>.unmodifiable(_trip.legs);
    final legsNotifier = ValueNotifier<List<TripLeg>>(List.of(initialLegs));
    final result = await showDialog<List<TripLeg>>(
      context: context,
      builder: (ctx) => ValueListenableBuilder<List<TripLeg>>(
        valueListenable: legsNotifier,
        builder: (context, legs, _) {
          final hasChange = legs.isNotEmpty && !_legsEqual(initialLegs, legs);
          return AppDialog(
            title: _l10n.editDestinations,
            content: TripLegsEditor(legsNotifier: legsNotifier),
            primaryLabel: _l10n.save,
            onPrimary: hasChange ? () => Navigator.pop(ctx, legs) : null,
            secondaryLabel: _l10n.cancel,
            onSecondary: () => Navigator.pop(ctx),
          );
        },
      ),
    );
    legsNotifier.dispose();

    if (result == null || result.isEmpty) return;
    await _updateTrip(_trip.copyWith(legs: result));
  }

  /// Field-by-field comparison — [TripLeg]/[LocationResult] don't override
  /// `==`, and identity comparison would miss a "removed then re-added the
  /// same destination" round trip that nets out to no real change.
  bool _legsEqual(List<TripLeg> a, List<TripLeg> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final la = a[i].location;
      final lb = b[i].location;
      if (la.name != lb.name ||
          la.latitude != lb.latitude ||
          la.longitude != lb.longitude ||
          la.timezone != lb.timezone ||
          a[i].dateRange.start != b[i].dateRange.start ||
          a[i].dateRange.end != b[i].dateRange.end) {
        return false;
      }
    }
    return true;
  }

  /// Persists a trip metadata edit (name/legs) and reflects it
  /// both locally and in [tripsProvider] — mirrors the optimistic-then-
  /// rollback pattern `TripsPage`'s equivalent used to follow before this
  /// menu moved here. A legs edit also reshuffles which dates the trip
  /// covers, so [_dayOutfits]/[_suitcaseIds] get refreshed from scratch
  /// afterward rather than trying to patch them in place.
  Future<void> _updateTrip(Trip updated) async {
    final previous = _trip;
    final legsChanged = !identical(updated.legs, previous.legs);
    setState(() => _trip = updated);
    ref.read(tripsProvider.notifier).updateTrip(updated);
    // The packing analysis is derived from legs/dates/activities — drop the
    // cached one so it's re-fetched (here and by the suitcase picker).
    ref.invalidate(tripSuggestionProvider(int.parse(previous.id)));
    try {
      // `legs` and `days` are independent on the backend — changing the leg
      // date range doesn't implicitly resize the day records, so a leg edit
      // has to resend `days` for the new range or added/removed days
      // silently don't take effect. Just the dates — the backend fills in
      // temperature on its own, and omitting `activity` keeps each
      // existing day's current value.
      final days = legsChanged
          ? updated.coveredDates
                .map((d) => {'date': DateFormat('yyyy-MM-dd').format(d)})
                .toList()
          : null;
      await TripService().updateTrip(
        int.parse(previous.id),
        name: updated.name != previous.name ? updated.name : null,
        legs: updated.legs,
        days: days,
      );
      if (legsChanged && mounted) {
        final refreshed = await TripDetailsPage.preload(updated);
        if (mounted) {
          setState(() {
            _dayOutfits = refreshed.days;
            _suitcaseIds = refreshed.suitcaseIds;
            _selectedDayIndex = _dayOutfits.isEmpty
                ? 0
                : _selectedDayIndex.clamp(0, _dayOutfits.length - 1);
          });
          _loadPackingAnalysis();
        }
      }
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => _trip = previous);
      ref.read(tripsProvider.notifier).updateTrip(previous);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _trip = previous);
      ref.read(tripsProvider.notifier).updateTrip(previous);
      debugLog('Failed to update trip: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateTrip)));
    }
  }

  Future<void> _confirmDeleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.deleteTrip,
        body: _l10n.deleteTripConfirmation,
        primaryLabel: _l10n.delete,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) => LoadingOverlay(label: _l10n.deletingTripEllipsis),
    );
    try {
      await TripService().deleteTrip(int.parse(_trip.id));
      if (!mounted) return;
      ref.read(tripsProvider.notifier).removeTrip(_trip.id);
      Navigator.pop(context); // close loading indicator
      Navigator.pop(context); // back out of Trip Details — the trip is gone
    } on AuthExpiredException {
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      debugLog('Failed to delete trip: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToDeleteTrip)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: _buildAppBar(),
          // A single scrollable list (rather than a fixed header Column with
          // only the bottom section scrolling) so dragging from anywhere on
          // screen — including the trip header/suitcase/day-selector area —
          // scrolls the whole page, not just the section below them.
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 20),
              _paddedSection(Text(_trip.name, style: AppTextStyle.bold20)),
              _paddedSection(
                const AppDivider(
                  topSpacing: 12,
                  bottomSpacing: AppDimens.sectionSpacing,
                ),
              ),
              _paddedSection(_TripDestinationsHeader(trip: _trip)),
              const SizedBox(height: AppDimens.sectionSpacing),
              _paddedSection(_buildSuitcaseSection()),
              const SizedBox(height: AppDimens.sectionSpacing),
              _paddedSection(_buildDayPlanCard()),
            ],
          ),
        ),
        if (_generatingOutfit)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingOutfitEllipsis),
          ),
        if (_loadingEditor)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingSuitcaseEllipsis),
          ),
        if (_replanningPlan)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingPlanEllipsis),
          ),
      ],
    );
  }

  Widget _paddedSection(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  Widget _buildDayPlanCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  SectionTitle(_l10n.dailyOutfitPlan),
                  // Only once there's an actual plan to replan — "I didn't
                  // touch the suitcase, I just want a different result" (see
                  // [_replanPlan]'s doc for how this differs from Suitcase's
                  // own "Replan Trip Outfits" button).
                  if (_hasTripPlan)
                    Positioned(
                      right: 0,
                      child: _buildHeaderIconButton(
                        icon: Icons.autorenew,
                        tooltip: _l10n.replanTripOutfits,
                        onTap:
                            (_replanActionInFlight || _dayOutfitActionInFlight)
                            ? null
                            : _replanPlan,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _buildTripDaySelector(),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _paddedSection(_buildOutfitDateHeader()),
          const SizedBox(height: AppDimens.cardHeaderGap),
          // The outfit image / "Generate Outfit" card only appears once the
          // *selected* day itself has something to show — an option, or
          // garments already assigned to it. Before that (a trip plan exists
          // for other days, but not this one — e.g. a newly added leg),
          // showing this card's own "no outfit planned yet" text on top of
          // the wardrobe section's "let Uwearis plan" CTA right below it
          // would just repeat the same message twice; the CTA alone carries
          // the next step.
          if (_selectedDayHasOption || _todayGarments.isNotEmpty) ...[
            _paddedSection(_buildOutfitSection()),
            const SizedBox(height: AppDimens.cardHeaderGap),
          ],
          _buildWardrobeSection(),
        ],
      ),
    );
  }

  /// The day's date/edit-button title, with the city it falls in folded in
  /// underneath as a quiet subtitle — rather than its own separate header
  /// block — so the two read as one piece of context instead of a stack of
  /// distinct sections. The city crossfades as the selected day moves
  /// between legs.
  Widget _buildOutfitDateHeader() {
    final date =
        _currentDayOutfit?.date ??
        _trip.dateRange.start.add(Duration(days: _selectedDayIndex));
    final dateStr = DateFormat('EEEE, MMM d').format(date);
    final hasOption = _currentDayOutfit?.optionId != null;
    final leg = _legForDate(date);
    final cityName = leg == null ? null : _cityOnly(leg.location.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionTitle(
                _l10n.outfitForDate(dateStr),
                style: AppTextStyle.regular16,
              ),
            ),
            // Regenerating lives on the image itself now (see
            // _buildOutfitSection's onRegenerate) — this header only still
            // carries Change Garments.
            if (hasOption)
              _buildHeaderIconButton(
                icon: Icons.edit_outlined,
                tooltip: _l10n.changeGarments,
                onTap: _openDayOutfitEditor,
              ),
          ],
        ),
        if (cityName != null) ...[
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Row(
              key: ValueKey(cityName),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  cityName,
                  style: AppTextStyle.regular13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// A small square icon action flush to the right edge of
  /// [_buildOutfitDateHeader]'s title row — currently just Change Garments
  /// (regenerating moved onto the image itself, see [_buildOutfitSection]).
  /// Right-aligned (not centered) within its touch target so the icon's own
  /// edge lines up with the Suitcase card's arrow above, rather than sitting
  /// visibly further in due to the touch target's padding.
  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: AppDimens.minTouchTarget,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(icon, size: 20, color: AppColors.icon),
            ),
          ),
        ),
      ),
    );
  }

  /// The selected day's outfit image. When the day has an option but no
  /// rendered image yet, its empty state is always a "Generate Outfit" /
  /// "Regenerate Outfit" button — disabled (with an explanation above it)
  /// while [_hasCoreOutfit] is false, since rendering an incomplete core
  /// selection isn't offered. Once an image exists, a corner badge on the
  /// image itself (styled like OutfitDetailsPage's own on-image icons — see
  /// [TodayOutfitIdea]) covers regenerating; Change Garments stays in
  /// [_buildOutfitDateHeader] above.
  Widget _buildOutfitSection() {
    final outfit = _currentDayOutfit;
    final outfitId = outfit?.outfitId;
    final needsRender = outfit?.optionId != null && outfitId == null;
    final hasCoreOutfit = _hasCoreOutfit;
    return TodayOutfitIdea(
      imageUrl: outfit?.resultImageUrl,
      hasAssignment: outfit?.optionId != null,
      isLoading: _generatingOutfit,
      jobStatus: _l10n.generatingOutfitEllipsis,
      cacheKey: outfitId == null ? null : 'trip-outfit-$outfitId',
      onRefreshUrl: outfitId == null ? null : _refreshOutfitImageUrl,
      onRegenerate: (outfitId == null || _dayOutfitActionInFlight)
          ? null
          : _generateSelectedDayOutfit,
      onGenerate: (needsRender && !_dayOutfitActionInFlight)
          ? _generateSelectedDayOutfit
          : null,
      generateEnabled: hasCoreOutfit,
      generateDisabledMessage: hasCoreOutfit
          ? null
          : _l10n.dayOutfitMissingCoreItemsMessage,
      generateLabel: (outfit?.everHadOutfit ?? false)
          ? _l10n.regenerateOutfit
          : _l10n.generateOutfit,
    );
  }

  /// Re-fetches the trip to get a freshly signed `result_image_url` for the
  /// currently selected day's outfit — the URL expires after 15 minutes,
  /// so a stale one can't just be reused.
  Future<String?> _refreshOutfitImageUrl() async {
    final outfitId = _currentDayOutfit?.outfitId;
    if (outfitId == null) return null;
    try {
      final tripData = await TripService().getTrip(int.parse(_trip.id));
      final rawDays = (tripData['days'] as List?) ?? [];
      if (_selectedDayIndex >= rawDays.length) return null;
      final day = rawDays[_selectedDayIndex];
      if (day is! Map<String, dynamic>) return null;
      final outfits = ((day['outfits'] as List?) ?? [])
          .whereType<Map<String, dynamic>>();
      for (final o in outfits) {
        if ((o['outfit_id'] as num?)?.toInt() == outfitId) {
          return o['result_image_url'] as String?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// A freely-scrolling day list — selection only changes when a card is
  /// tapped (no more "whichever page is centered" from swiping). Tapping a
  /// card scrolls it fully into view if it's partially cut off at an edge,
  /// but otherwise leaves the scroll position alone instead of forcing the
  /// selected card to the center.
  Widget _buildTripDaySelector() {
    // Trusts the trip's actual day count/order over the theoretical span
    // (dateRange.start..end) — the backend's days[] isn't guaranteed to
    // tile that span with zero gaps (e.g. multi-leg trips with a stretch
    // between legs covered by no leg at all), so computing a card count
    // from the span can drift out of sync with what _dayOutfits[index]
    // actually holds.
    final int totalDays = _dayOutfits.length;
    return EdgeFadeScrim(
      child: SizedBox(
        height: _dayCardHeight,
        child: ListView.separated(
          controller: _dayScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: totalDays,
          separatorBuilder: (_, _) => const SizedBox(width: _dayCardGap),
          itemBuilder: (context, index) {
            final dayOutfit = index < _dayOutfits.length
                ? _dayOutfits[index]
                : null;
            final date =
                dayOutfit?.date ??
                _trip.dateRange.start.add(Duration(days: index));
            return TripDayCard(
              date: date,
              isSelected: index == _selectedDayIndex,
              temperatureMaxC: dayOutfit?.temperatureMaxC,
              temperatureMinC: dayOutfit?.temperatureMinC,
              onTap: () => _selectDay(index),
            );
          },
        ),
      ),
    );
  }

  void _selectDay(int index) {
    setState(() => _selectedDayIndex = index);
    _scrollDayIntoView(index);
  }

  /// Scrolls the day selector by the minimum amount needed to bring [index]
  /// fully on screen — unlike centering, a card already visible (even at an
  /// edge) is left where it is.
  void _scrollDayIntoView(int index) {
    if (!_dayScrollController.hasClients) return;
    final position = _dayScrollController.position;
    const double leadingPadding = 16;
    const double slotWidth = _dayCardWidth + _dayCardGap;
    final itemStart = leadingPadding + index * slotWidth;
    final itemEnd = itemStart + _dayCardWidth;
    final viewStart = position.pixels;
    final viewEnd = viewStart + position.viewportDimension;

    double? target;
    if (itemStart < viewStart) {
      target = itemStart - leadingPadding;
    } else if (itemEnd > viewEnd) {
      target = itemEnd - position.viewportDimension + leadingPadding;
    }
    if (target == null) return;
    _dayScrollController.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  TripLeg? _legForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    for (final leg in _trip.legs) {
      final start = leg.dateRange.start;
      final end = leg.dateRange.end;
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      if (!day.isBefore(startDay) && !day.isAfter(endDay)) return leg;
    }
    return null;
  }

  /// [LocationResult.name] is stored as "City, Country" — the city header only
  /// has room for (and only wants) the city part.
  String _cityOnly(String locationName) => locationName.split(',').first.trim();

  Widget _buildWardrobeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_todayGarments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _selectedDayHasOption
                ? EmptyStatePlaceholder(
                    message: _l10n.noItemsPlanned,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                  )
                : _GeneratePlanCta(onTap: _openSuitcase),
          )
        else ...[
          EdgeFadeScrim(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _todayGarments.length,
                itemBuilder: (context, index) {
                  final g = _todayGarments[index];
                  return _TripGarmentThumb(
                    garment: g,
                    isMissing: g.id != null && !_suitcaseIds.contains(g.id),
                    onTap: () => GarmentDetailDialog.show(context, g),
                  );
                },
              ),
            ),
          ),
          if (_hasMissingSuitcaseItems) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMissingItemsWarning(),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildMissingItemsWarning() {
    final missingCount = _todayGarments
        .where((g) => g.id != null && !_suitcaseIds.contains(g.id))
        .length;
    if (missingCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _l10n.missingFromSuitcaseCount(missingCount),
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _fixMissingSuitcaseItems,
            child: Text(
              _l10n.addToSuitcase,
              style: AppTextStyle.semibold14.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuitcaseSection() {
    final packedCount = _suitcaseIds.length;
    final recommended = _recommendedTotal;
    final summary = packedCount == 0
        ? _l10n.packClothingHint
        : (recommended != null
              ? _l10n.recommendedSelectedCount(recommended, packedCount)
              : _l10n.packedItemsCount(packedCount));

    return AppListCard(
      title: _l10n.suitcaseLabel,
      leading: const Icon(Icons.luggage_outlined, color: AppColors.icon),
      showArrow: true,
      onTap: _openSuitcase,
      child: Text(
        summary,
        style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// The trip's destinations + date ranges, one row per leg — a static readout
/// of [trip]'s own metadata with no interaction of its own.
class _TripDestinationsHeader extends StatelessWidget {
  final Trip trip;

  const _TripDestinationsHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < trip.legs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.legs[i].location.name,
                  style: AppTextStyle.bold16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${DateFormat('MMM d').format(trip.legs[i].dateRange.start)} - "
                "${DateFormat('MMM d').format(trip.legs[i].dateRange.end)}",
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The "let Uwearis plan your outfits" call-to-action card shown while a trip
/// still has no plan — the [AccentPillButton] opens [TripSuitcasePage], which
/// owns plan generation now (see [_TripDetailsPageState._openSuitcase]).
class _GeneratePlanCta extends StatelessWidget {
  final VoidCallback onTap;

  const _GeneratePlanCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          SectionTitle(l10n.letUwearisPlanOutfits),
          const SizedBox(height: 4),
          Text(
            l10n.letUwearisPlanOutfitsHint,
            textAlign: TextAlign.center,
            style: AppTextStyle.regular13.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          AccentPillButton(
            label: l10n.planTripOutfits,
            icon: Icons.auto_awesome,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// One 80px-wide thumbnail in a trip day's horizontal garment strip, with an
/// error badge when [isMissing] (the garment is no longer in the suitcase).
class _TripGarmentThumb extends StatelessWidget {
  final Garment garment;
  final bool isMissing;
  final VoidCallback? onTap;

  const _TripGarmentThumb({
    required this.garment,
    required this.isMissing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque so the whole thumb is tappable even when the garment image
      // falls back to a small centered placeholder icon.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                // contain, not cover — this box is portrait-ish (80x100)
                // while a garment photo isn't necessarily; cover would crop
                // a wide/short photo (e.g. shoes) down to an unrecognizable
                // sliver instead of showing the whole garment. Matches
                // GarmentCard/GarmentListCard's own thumbnails. A little
                // inset so a contained image doesn't touch the card's own
                // rounded border.
                padding: const EdgeInsets.all(6),
                child: GarmentImage(
                  url: garment.imageUrl,
                  garmentId: garment.id,
                  memCacheWidth: 160,
                  fit: BoxFit.contain,
                  borderRadius: 0,
                ),
              ),
            ),
            if (isMissing)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.error,
                  size: 16,
                  color: AppColors.error,
                  shadows: [Shadow(color: AppColors.surface, blurRadius: 3)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
