import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/trip_detail_provider.dart';
import '../../core/providers/trip_suggestion_provider.dart';
import '../../core/providers/trips_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/trip.dart';
import '../../data/trip_plan.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/circle_icon_button.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/generated_image_card.dart';
import '../widgets/common/edge_fade_scrim.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_image.dart';
import '../widgets/trip/replan_confirm_dialog.dart';
import '../widgets/trip/trip_day_card.dart';
import '../widgets/trip/trip_legs_editor.dart';
import 'outfit_edit_page.dart';
import 'trip_suitcase_page.dart';

/// Actions in [TripDetailsPage]'s app bar "⋮" menu — moved here from
/// [TripCard] (the Trips-tab list item) so a trip's own metadata edits live
/// on its detail page instead of duplicated across every card that links
/// to it.
enum _TripMenuAction { editName, editLegs, delete }

/// Renders from [tripDetailProvider] — the caller loads it before pushing
/// (see `openTripDetails`), so only a trip's first visit waits on the
/// network.
class TripDetailsPage extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage> {
  // TripDayCard's own width plus the gap between cards — used to compute
  // how far to scroll the day selector to bring a tapped card into view.
  static const double _dayCardWidth = 95;
  static const double _dayCardGap = 8;
  // Snug around TripDayCard's tallest state (date row + temperature line);
  // the cards stretch to this so temp / no-temp days stay the same height.
  static const double _dayCardHeight = 78;

  int _selectedDayIndex = 0;
  final ScrollController _dayScrollController = ScrollController();

  // Which EdgeFadeScrim edges still have something to fade — start
  // fully-visible (matching EdgeFadeScrim's own always-visible default) and
  // get corrected by the first ScrollMetricsNotification each row's
  // NotificationListener sees, which fires on initial layout as well as on
  // every real scroll/content-size change (see _applyEdgeFadeVisibility).
  bool _daySelectorFadeLeftVisible = true;
  bool _daySelectorFadeRightVisible = true;
  bool _wardrobeFadeLeftVisible = true;
  bool _wardrobeFadeRightVisible = true;

  // Mutable local copy — the app bar's edit menu (name/itinerary/
  // activities) needs to update what's on screen immediately, and
  // [widget.trip] is otherwise a fixed snapshot from whoever pushed this
  // page. Kept in sync with [tripsProvider] by [_updateTrip].
  late Trip _trip = widget.trip;

  int get _tripId => int.parse(_trip.id);

  TripDetail get _detail =>
      ref.read(tripDetailProvider(_tripId)).value ?? const TripDetail();

  TripDetailNotifier get _detailNotifier =>
      ref.read(tripDetailProvider(_tripId).notifier);

  List<TripDayOutfit> get _dayOutfits => _detail.days;
  Set<int> get _suitcaseIds => _detail.suitcaseIds;

  // Display-only — feeds the "Recommended N · Selected M" summary on the
  // Suitcase card (see [_buildSuitcaseSection]). Packing guidance, never a
  // plan-generation gate — that lives on TripSuitcasePage now.
  int? _recommendedTotal;
  bool _generatingOutfit = false;
  // Re-entrancy guard for the *whole* generate/regenerate-day-outfit flow,
  // including the regenerate confirm dialog — see [_generateSelectedDayOutfit].
  bool _dayOutfitActionInFlight = false;
  // Same shape as [_dayOutfitActionInFlight], for the whole-trip Replan
  // triggered from the Daily Outfit Plan refresh icon — see [_replanPlan].
  bool _replanActionInFlight = false;
  bool _replanningPlan = false;
  // Guards the whole itinerary-edit flow (the edit dialog plus the
  // save-and-reanalyze work that follows a legs change) — see
  // [_editTripLegs]. [_updatingTripLegs] is the narrower flag that only
  // covers that save-and-reanalyze work, for the loading overlay: it starts
  // the instant Save is tapped (dialog closed) and spans the PATCH, the plan
  // refetch, and the AI reanalysis together, since all three are awaited
  // back-to-back with nothing else to show progress in between — flipping it
  // on only around the last (AI) step left a multi-second gap after Save
  // with no visible feedback at all.
  bool _editLegsActionInFlight = false;
  bool _updatingTripLegs = false;

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

  bool get _hasTripPlan => _detail.hasTripPlan;

  /// Whether the *selected* day specifically has an option assigned — unlike
  /// [_hasTripPlan] (any day at all), this gates [_buildWardrobeSection]'s
  /// Generate button and its "let Uwearis plan" CTA for the day currently
  /// on screen (e.g. a leg added after the plan was first generated still
  /// has no option of its own even though other days do).
  bool get _selectedDayHasOption => _currentDayOutfit?.optionId != null;

  /// Whether today's assigned garments cover Top, Bottom, and Shoes — a
  /// one-piece counts for both Top and Bottom, mirroring AddOutfitPage's own
  /// core-completeness rule. Gates the "Generate Outfit" button's *enabled*
  /// state ([_buildGenerateOutfitButton]): the button itself always shows once a
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
    // A reload can shrink the day list (an itinerary edit) out from under
    // the selected index.
    ref.listenManual(tripDetailProvider(_tripId), (_, next) {
      final dayCount = next.value?.days.length ?? 0;
      final clamped = dayCount == 0
          ? 0
          : _selectedDayIndex.clamp(0, dayCount - 1);
      if (clamped != _selectedDayIndex) {
        setState(() => _selectedDayIndex = clamped);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _revalidateIfStale());
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  /// A revisit renders the cached [tripDetailProvider] as-is; once its
  /// signed image URLs have expired (15 minutes), re-fetch it in the
  /// background so images don't each have to re-sign themselves one by one.
  Future<void> _revalidateIfStale() async {
    if (!_detail.hasStaleImages) return;
    try {
      await _detailNotifier.reloadTripDetail();
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      // Keep the cached detail; each image still refreshes its own URL on
      // failure.
      debugLog('Failed to revalidate trip detail: $e');
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

  /// Force-reruns the AI packing analysis (`POST .../packing-analysis`) after
  /// an itinerary edit changes the trip's legs/dates — called from
  /// [_updateTrip]'s `legsChanged` branch. Unlike [_loadPackingAnalysis],
  /// which only re-reads whatever [tripSuggestionProvider] already has
  /// cached, this asks the backend to actually recompute the analysis for
  /// the new legs, since [_updateTrip] already invalidated that cache and a
  /// plain re-read would otherwise still return the pre-edit result. Doesn't
  /// own [_updatingTripLegs] itself — [_editTripLegs] holds that flag for
  /// this call and the awaits before it, see its doc comment.
  Future<void> _analyzeTrip() async {
    try {
      final analysis = await TripService().analyzeTrip(int.parse(_trip.id));
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
    } catch (e) {
      if (!mounted) return;
      debugLog('Failed to analyze trip: $e');
    }
  }

  /// Re-fetches this trip's plan after a `generate` changed it server-side.
  /// A failure keeps the cached plan rather than wiping it.
  Future<void> _reloadPlan() async {
    try {
      await _detailNotifier.reloadPlan();
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
  /// `getTripPlan` round trip needed. On success this refreshes in place
  /// ([_reloadPlan]) rather than popping anywhere.
  Future<void> _replanPlan() async {
    if (_replanActionInFlight ||
        _dayOutfitActionInFlight ||
        _editLegsActionInFlight) {
      return;
    }
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
        await _reloadPlan();
      } on AuthExpiredException {
        if (mounted) await AuthExpiredHandler.handle(context);
      } catch (e) {
        debugLog('Failed to replan trip: $e');
        if (mounted) {
          showErrorDialog(context, message: _l10n.failedToGeneratePlan);
        }
      } finally {
        if (mounted) setState(() => _replanningPlan = false);
      }
    } finally {
      if (mounted) setState(() => _replanActionInFlight = false);
    }
  }

  // The Suitcase page writes its changes back to tripDetailProvider, which
  // this page watches — nothing to re-fetch on return.
  Future<void> _openSuitcase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip)),
    );
  }

  /// Synchronously renders the *currently selected* day's option into a
  /// try-on image — reachable from the "Generate"/"Regenerate Outfit" button
  /// under the day's garments ([_buildGenerateOutfitButton]) or the corner
  /// regenerate badge on the image itself once one already exists
  /// ([_buildOutfitSection]'s `onRegenerate`). Branches on whether this option already has an
  /// `outfit_id` —
  /// the backend now splits first render ([TripService.generateOptionOutfit],
  /// 409s if already rendered) from re-rendering an existing one
  /// ([TripService.regenerateOptionOutfit], 400s if never rendered) into two
  /// endpoints, so calling the wrong one for the option's current state
  /// fails outright. The result is applied to whichever day still holds the
  /// same option ([TripDetailNotifier.updateDayOutfit]), so a slow request
  /// landing after the user has switched days can't clobber a different
  /// day's state.
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
    if (_dayOutfitActionInFlight || _editLegsActionInFlight) return;
    setState(() => _dayOutfitActionInFlight = true);
    try {
      final before = _dayOutfits[_selectedDayIndex];
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
      // Read before the await — the result is written back even if the
      // user has left the page by the time the render lands.
      final detailNotifier = _detailNotifier;
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
        detailNotifier.updateDayOutfit(
          optionId,
          (current) => TripDayOutfit(
            date: current.date,
            optionId: optionId,
            garments: current.garments,
            outfitId: result.outfitId,
            resultImageUrl: result.resultImageUrl,
            temperatureMaxC: current.temperatureMaxC,
            temperatureMinC: current.temperatureMinC,
            everHadOutfit: true,
            isManuallyEdited: current.isManuallyEdited,
          ),
        );
      } on AuthExpiredException {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      } catch (e) {
        debugLog('Failed to generate day outfit: $e');
        if (mounted) {
          showErrorDialog(context, message: _l10n.failedToGenerateOutfit);
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

    final result = await Navigator.push<OutfitEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitEditPage(
          initialGarments: _todayGarments,
          preloadedGarments: _detail.suitcase,
          validGarmentIds: _suitcaseIds,
          title: _l10n.editOutfitTitle,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final detailNotifier = _detailNotifier;
    try {
      final newGarments = await TripService().updateOptionItems(
        _tripId,
        optionId: optionId,
        garmentIds: result.garmentIds.toList(),
      );
      // updateOptionItems clears this option's already-tried-on outfit
      // server-side (see its doc comment) — outfitId/resultImageUrl drop to
      // null here to match, rather than keeping the now-stale values around.
      // everHadOutfit stays sticky so the CTA reads "Regenerate" rather than
      // "Generate" once the user does render this slot again.
      detailNotifier.updateDayOutfit(
        optionId,
        (current) => TripDayOutfit(
          date: current.date,
          optionId: optionId,
          temperatureMaxC: current.temperatureMaxC,
          temperatureMinC: current.temperatureMinC,
          garments: newGarments,
          everHadOutfit: current.everHadOutfit,
          isManuallyEdited: true,
        ),
      );
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to update day outfit: $e');
      if (mounted) {
        showErrorDialog(context, message: _l10n.failedToUpdateDayOutfit);
      }
    }
  }

  /// "Fix" action for the missing-items warning: re-adds whatever's
  /// currently in this day's outfit but missing from the suitcase back into
  /// it, rather than making the user go re-pick the outfit.
  Future<void> _fixMissingSuitcaseItems() async {
    final missing = _todayGarments
        .where((g) => g.id != null && !_suitcaseIds.contains(g.id))
        .toList();
    if (missing.isEmpty) return;

    final detailNotifier = _detailNotifier;
    try {
      for (final g in missing) {
        await TripService().addSuitcaseItem(_tripId, garmentId: g.id!);
        detailNotifier.addSuitcaseGarments([g]);
      }
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to re-add missing suitcase items: $e');
      if (mounted) {
        showErrorDialog(context, message: _l10n.failedToUpdateSuitcase);
      }
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _l10n.tripDetailsTitle,
      actions: [
        AppPopupMenu<_TripMenuAction>(
          variant: AppPopupMenuVariant.toolbar,
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
              label: _l10n.editItinerary,
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

  /// Guarded the same way as [_replanPlan]/[_generateSelectedDayOutfit]:
  /// [_editLegsActionInFlight] covers the whole flow (dialog included), not
  /// just the save-and-reanalyze work [_updateTrip] does afterward when legs
  /// actually change — see CLAUDE.md "Guarding costly / mutating actions
  /// against double-invocation". [_updatingTripLegs] is the narrower visible-
  /// loading flag for that save-and-reanalyze work specifically (see its own
  /// doc comment for why it starts here rather than deeper inside
  /// [_analyzeTrip]).
  Future<void> _editTripLegs() async {
    if (_editLegsActionInFlight ||
        _replanActionInFlight ||
        _dayOutfitActionInFlight) {
      return;
    }
    setState(() => _editLegsActionInFlight = true);
    try {
      final initialLegs = List<TripLeg>.unmodifiable(_trip.legs);
      final legsNotifier = ValueNotifier<List<TripLeg>>(List.of(initialLegs));
      final result = await showDialog<List<TripLeg>>(
        context: context,
        builder: (ctx) => ValueListenableBuilder<List<TripLeg>>(
          valueListenable: legsNotifier,
          builder: (context, legs, _) {
            final hasChange = legs.isNotEmpty && !_legsEqual(initialLegs, legs);
            return AppDialog(
              title: _l10n.editItinerary,
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
      setState(() => _updatingTripLegs = true);
      try {
        await _updateTrip(_trip.copyWith(legs: result));
      } finally {
        if (mounted) setState(() => _updatingTripLegs = false);
      }
    } finally {
      if (mounted) setState(() => _editLegsActionInFlight = false);
    }
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
  /// covers, so the plan gets re-fetched afterward rather than patched in
  /// place.
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
        await _reloadPlan();
        if (mounted) await _analyzeTrip();
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
      showErrorDialog(context, message: _l10n.failedToUpdateTrip);
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
      showErrorDialog(context, message: _l10n.failedToDeleteTrip);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes this page to the shared detail; the helpers read it through
    // [_detail].
    ref.watch(tripDetailProvider(_tripId));
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
              _paddedSection(_TripItineraryHeader(trip: _trip)),
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
        if (_replanningPlan)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingPlanEllipsis),
          ),
        if (_updatingTripLegs)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.updatingTripEllipsis),
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
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
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
                      child: CircleIconButton(
                        icon: Icons.autorenew,
                        tooltip: _l10n.replanTripOutfits,
                        discAlignment: Alignment.centerRight,
                        onPressed:
                            (_replanActionInFlight ||
                                _dayOutfitActionInFlight ||
                                _editLegsActionInFlight)
                            ? null
                            : _replanPlan,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.sectionSpacing),
          _buildTripDaySelector(),
          const SizedBox(height: AppDimens.sectionSpacing),
          _buildWardrobeSection(),
          // Takes the Generate button's place under the garments once the
          // day is rendered.
          if (_hasOutfitImage) ...[
            const SizedBox(height: AppDimens.sectionSpacing),
            _paddedSection(_buildOutfitSection()),
          ],
        ],
      ),
    );
  }

  bool get _hasOutfitImage =>
      _currentDayOutfit?.resultImageUrl?.isNotEmpty ?? false;

  /// The selected day's rendered outfit image, with a corner badge on the
  /// image itself (styled like OutfitDetailsPage's own on-image icons — see
  /// [GeneratedImageCard]) for regenerating. Only built once
  /// [_hasOutfitImage].
  Widget _buildOutfitSection() {
    final outfitId = _currentDayOutfit?.outfitId;
    return GeneratedImageCard(
      imageUrl: _currentDayOutfit?.resultImageUrl,
      isLoading: _generatingOutfit,
      jobStatus: _l10n.generatingOutfitEllipsis,
      errorLabel: _l10n.generatingOutfitEllipsis,
      cacheKey: outfitId == null ? null : 'trip-outfit-$outfitId',
      onRefreshUrl: outfitId == null ? null : _refreshOutfitImageUrl,
      onRegenerate:
          (outfitId == null ||
              _dayOutfitActionInFlight ||
              _editLegsActionInFlight)
          ? null
          : _generateSelectedDayOutfit,
    );
  }

  /// The selected day's first (or, after a garment edit cleared the old
  /// render, repeat) render trigger — shown under its garments once the day
  /// has an option but no image. Stays visible but disabled, with an
  /// explanation, while [_hasCoreOutfit] is false, since rendering an
  /// incomplete core selection isn't offered.
  Widget _buildGenerateOutfitButton() {
    final hasCoreOutfit = _hasCoreOutfit;
    return AccentPillButton(
      icon: Icons.auto_awesome,
      label: (_currentDayOutfit?.everHadOutfit ?? false)
          ? _l10n.regenerateOutfit
          : _l10n.generateOutfit,
      enabled: hasCoreOutfit,
      disabledMessage: hasCoreOutfit
          ? null
          : _l10n.dayOutfitMissingCoreItemsMessage,
      onPressed: (_dayOutfitActionInFlight || _editLegsActionInFlight)
          ? null
          : _generateSelectedDayOutfit,
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
      leftVisible: _daySelectorFadeLeftVisible,
      rightVisible: _daySelectorFadeRightVisible,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _applyEdgeFadeVisibility(
            notification.metrics,
            _daySelectorFadeLeftVisible,
            _daySelectorFadeRightVisible,
            (left, right) {
              _daySelectorFadeLeftVisible = left;
              _daySelectorFadeRightVisible = right;
            },
          );
          return false;
        },
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

  /// Recomputes which edge(s) of an [EdgeFadeScrim] row still have content
  /// to fade from [metrics] — [currentLeft]/[currentRight] are that row's
  /// own current flags, [apply] writes the new ones back into its two
  /// fields. Shared by the day selector's and wardrobe row's
  /// `NotificationListener<ScrollNotification>` (both real scroll updates
  /// and content-size changes deliver a ScrollMetricsNotification here, so
  /// this covers initial layout too — no separate post-frame callback
  /// needed).
  void _applyEdgeFadeVisibility(
    ScrollMetrics metrics,
    bool currentLeft,
    bool currentRight,
    void Function(bool left, bool right) apply,
  ) {
    final left = metrics.pixels > metrics.minScrollExtent;
    final right = metrics.pixels < metrics.maxScrollExtent;
    if (left != currentLeft || right != currentRight) {
      setState(() => apply(left, right));
    }
  }

  Widget _buildWardrobeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDayHasOption || _todayGarments.isNotEmpty) ...[
          _paddedSection(_buildOutfitItemsHeader()),
          const SizedBox(height: AppDimens.cardHeaderGap),
        ],
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
            leftVisible: _wardrobeFadeLeftVisible,
            rightVisible: _wardrobeFadeRightVisible,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _applyEdgeFadeVisibility(
                  notification.metrics,
                  _wardrobeFadeLeftVisible,
                  _wardrobeFadeRightVisible,
                  (left, right) {
                    _wardrobeFadeLeftVisible = left;
                    _wardrobeFadeRightVisible = right;
                  },
                );
                return false;
              },
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
          ),
          if (_hasMissingSuitcaseItems) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMissingItemsWarning(),
            ),
          ],
        ],
        if (_selectedDayHasOption && _currentDayOutfit?.outfitId == null) ...[
          const SizedBox(height: AppDimens.sectionSpacing),
          Center(child: _buildGenerateOutfitButton()),
        ],
      ],
    );
  }

  /// Change Garments PATCHes the day's option, so it's only offered once
  /// the selected day has one.
  Widget _buildOutfitItemsHeader() {
    return Row(
      children: [
        Expanded(child: FieldLabel(_l10n.outfitItemsLabel.toUpperCase())),
        if (_selectedDayHasOption)
          CircleIconButton(
            icon: Icons.edit_outlined,
            tooltip: _l10n.changeGarments,
            discAlignment: Alignment.centerRight,
            onPressed: _openDayOutfitEditor,
          ),
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

/// The trip's itinerary + date ranges, one row per leg — a static readout
/// of [trip]'s own metadata with no interaction of its own.
class _TripItineraryHeader extends StatelessWidget {
  final Trip trip;

  const _TripItineraryHeader({required this.trip});

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
