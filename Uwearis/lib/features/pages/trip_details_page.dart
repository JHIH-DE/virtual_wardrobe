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

enum _TripMenuAction { editName, editLegs, delete }

/// Renders from [tripDetailProvider]; `openTripDetails` loads it before
/// pushing, so only a trip's first visit waits on the network.
class TripDetailsPage extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage> {
  // Must match TripDayCard's width (used for scroll-into-view math).
  static const double _dayCardWidth = 95;
  static const double _dayCardGap = 8;
  // Fits TripDayCard's tallest state so days with/without a temperature
  // line stay the same height.
  static const double _dayCardHeight = 78;

  int _selectedDayIndex = 0;
  final ScrollController _dayScrollController = ScrollController();

  // Corrected by the first ScrollMetricsNotification, which also fires on
  // initial layout.
  bool _daySelectorFadeLeftVisible = true;
  bool _daySelectorFadeRightVisible = true;
  bool _wardrobeFadeLeftVisible = true;
  bool _wardrobeFadeRightVisible = true;

  // Local copy so name/itinerary edits show immediately; [_updateTrip]
  // keeps [tripsProvider] in sync.
  late Trip _trip = widget.trip;

  int get _tripId => int.parse(_trip.id);

  TripDetail get _detail =>
      ref.read(tripDetailProvider(_tripId)).value ?? const TripDetail();

  TripDetailNotifier get _detailNotifier =>
      ref.read(tripDetailProvider(_tripId).notifier);

  List<TripDayOutfit> get _dayOutfits => _detail.days;
  Set<int> get _suitcaseIds => _detail.suitcaseIds;

  // Display-only ("Recommended N · Selected M" on the Suitcase card), not a
  // plan-generation gate.
  int? _recommendedTotal;
  bool _generatingOutfit = false;
  bool _dayOutfitActionInFlight = false;
  bool _replanActionInFlight = false;
  bool _replanningPlan = false;
  bool _editLegsActionInFlight = false;
  // Overlay spans the PATCH, plan refetch and AI reanalysis together, so
  // there's no feedback gap after Save.
  bool _updatingTripLegs = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  TripDayOutfit? get _currentDayOutfit => _selectedDayIndex < _dayOutfits.length
      ? _dayOutfits[_selectedDayIndex]
      : null;

  List<Garment> get _todayGarments => _currentDayOutfit?.garments ?? const [];

  /// Some of the selected day's garments are no longer in the suitcase.
  bool get _hasMissingSuitcaseItems =>
      _todayGarments.any((g) => g.id != null && !_suitcaseIds.contains(g.id));

  bool get _hasTripPlan => _detail.hasTripPlan;

  /// Per day, unlike [_hasTripPlan]: a leg added after planning has no
  /// option even though other days do.
  bool get _selectedDayHasOption => _currentDayOutfit?.optionId != null;

  /// Top + Bottom + Shoes (a one-piece covers Top and Bottom). Gates whether
  /// the Generate Outfit button is enabled.
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

  /// Once the cached detail's signed image URLs expire, re-fetch it in the
  /// background so images don't each re-sign one by one.
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

  Future<void> _loadPackingAnalysis() async {
    try {
      // Cached provider, shared with the suitcase page and garment picker.
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

  /// Asks the backend to recompute the packing analysis after a legs edit;
  /// a plain re-read would return the pre-edit result.
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

  /// Replan without a suitcase change ("I just don't like what Uwearis
  /// picked"); TripSuitcasePage's Replan only shows after a suitcase change.
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

  /// First render vs. re-render are separate endpoints (generate 409s if
  /// already rendered, regenerate 400s if never rendered), so branch on
  /// `outfitId`. The result is applied by option id, so a slow response
  /// after a day switch can't clobber another day.
  Future<void> _generateSelectedDayOutfit() async {
    if (_dayOutfitActionInFlight || _editLegsActionInFlight) return;
    setState(() => _dayOutfitActionInFlight = true);
    try {
      final before = _dayOutfits[_selectedDayIndex];
      final optionId = before.optionId;
      if (optionId == null) return;
      final isRegenerate = before.outfitId != null;

      // Regenerating discards the current render for a new paid one.
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

  /// Needs an existing option to PATCH.
  Future<void> _openDayOutfitEditor() async {
    final optionId = _currentDayOutfit?.optionId;
    if (optionId == null) return;

    final garmentIds = await Navigator.push<Set<int>>(
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
    if (garmentIds == null || !mounted) return;

    final detailNotifier = _detailNotifier;
    try {
      final newGarments = await TripService().updateOptionItems(
        _tripId,
        optionId: optionId,
        garmentIds: garmentIds.toList(),
      );
      // The backend clears the option's rendered outfit, so drop
      // outfitId/resultImageUrl; everHadOutfit stays so the CTA reads
      // "Regenerate".
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

  /// Re-packs the day's garments that are missing from the suitcase.
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

  /// [TripLeg]/[LocationResult] don't override `==`.
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

  /// Optimistic update with rollback. A legs edit changes the covered dates,
  /// so the plan is re-fetched rather than patched.
  Future<void> _updateTrip(Trip updated) async {
    final previous = _trip;
    final legsChanged = !identical(updated.legs, previous.legs);
    setState(() => _trip = updated);
    ref.read(tripsProvider.notifier).updateTrip(updated);
    // The packing analysis is derived from legs/dates/activities.
    ref.invalidate(tripSuggestionProvider(int.parse(previous.id)));
    try {
      // The backend doesn't resize `days` from `legs`, so resend the dates.
      // Omitting `activity` keeps each day's value; temperature is filled in
      // server-side.
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
      Navigator.pop(context); // the trip is gone
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
    // Helpers read the detail through [_detail].
    ref.watch(tripDetailProvider(_tripId));
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: _buildAppBar(),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 20),
              _paddedSection(Text(_trip.name, style: AppTextStyle.bold20)),
              const SizedBox(height: AppDimens.titleGap),
              _paddedSection(_TripItineraryHeader(trip: _trip)),
              const SizedBox(height: 24),
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

  /// Shown once the day has an option but no render; disabled with an
  /// explanation while [_hasCoreOutfit] is false.
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

  /// Re-fetches the trip for a freshly signed `result_image_url`.
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

  Widget _buildTripDaySelector() {
    // Uses the actual days[], not the dateRange span: multi-leg trips can
    // have gaps between legs.
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

  /// Scrolls the minimum needed to bring [index] fully on screen; a fully
  /// visible card doesn't move.
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

  /// Updates an [EdgeFadeScrim] row's edge flags from [metrics] via [apply].
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

class _TripItineraryHeader extends StatelessWidget {
  final Trip trip;

  const _TripItineraryHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < trip.legs.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
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

/// Shown while the day has no plan; opens [TripSuitcasePage], where plans
/// are generated.
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

/// [isMissing]: the garment is no longer in the suitcase.
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
                // contain: cover would crop wide photos (e.g. shoes).
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
