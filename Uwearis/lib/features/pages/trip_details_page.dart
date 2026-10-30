import 'dart:async';

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
import '../../data/outfit.dart';
import '../../data/trip.dart';
import '../../data/trip_outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/action_button.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/common/section_header.dart';
import '../widgets/outfit/outfit_card.dart';
import '../widgets/outfit/outfit_grid.dart';
import '../widgets/trip/trip_legs_editor.dart';
import '../widgets/trip/trip_collection_actions.dart';
import '../widgets/trip/trip_outfit_tile.dart';
import 'outfit_edit_page.dart';
import 'trip_outfit_detail_page.dart';
import 'trip_outfit_version_page.dart';
import 'trip_suitcase_page.dart';
import '../../core/utils/date_locale.dart';

enum _TripMenuAction { editName, editLegs, delete }

/// Renders from [tripDetailProvider]; `openTripDetails` loads it before
/// pushing, so only a trip's first visit waits on the network.
class TripDetailsPage extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage>
    with TripCollectionActions {
  // Local copy so name/itinerary edits show immediately; [_updateTrip]
  // keeps [tripsProvider] in sync.
  late Trip _trip = widget.trip;

  int get _tripId => int.parse(_trip.id);

  @override
  int get tripId => _tripId;

  TripOutfitCollection get _detail =>
      ref.read(tripDetailProvider(_tripId)).value ??
      const TripOutfitCollection();

  TripDetailNotifier get _detailNotifier =>
      ref.read(tripDetailProvider(_tripId).notifier);

  bool _generatingOutfits = false;
  bool _editLegsActionInFlight = false;
  // Overlay spans the PATCH, collection refetch and AI reanalysis together,
  // so there's no feedback gap after Save.
  bool _updatingTripLegs = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool get _actionsLocked =>
      isCollectionActionInFlight || _editLegsActionInFlight;

  @override
  void initState() {
    super.initState();
    _loadPackingAnalysis();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revalidateIfStale());
  }

  /// Once the cached detail's signed image URLs expire, re-fetch it in the
  /// background so images don't each re-sign one by one.
  Future<void> _revalidateIfStale() async {
    if (!_detail.hasStaleImages) return;
    await _reloadCollection();
  }

  /// A failure keeps the cached collection rather than wiping it.
  Future<void> _reloadCollection() async {
    try {
      await _detailNotifier.reloadTripDetail();
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Failed to reload trip outfits: $e');
    }
  }

  Future<void> _loadPackingAnalysis() async {
    try {
      // Warms the cached provider the suitcase page and garment picker read.
      await ref.read(tripSuggestionProvider(_tripId).future);
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
      await TripService().analyzeTrip(_tripId);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('Failed to analyze trip: $e');
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Plan / Find More / Refresh. A result with nothing new is a normal
  /// outcome, not an error.
  Future<void> _generateOutfits(TripOutfitGenerateMode mode) async {
    if (_editLegsActionInFlight) return;
    final replaceable = _detail.replaceableOutfits.length;
    await runCollectionAction(
      fallback: _l10n.failedToGeneratePlan,
      request: () async {
        if (mode == TripOutfitGenerateMode.refresh &&
            !await _confirmRefresh(replaceable)) {
          return null;
        }
        if (!mounted) return null;
        setState(() => _generatingOutfits = true);
        final TripOutfitGenerateResult result;
        try {
          result = await TripService().generateTripOutfits(_tripId, mode: mode);
        } finally {
          if (mounted) setState(() => _generatingOutfits = false);
        }
        if (mounted) {
          if (result.generatedCount > 0) {
            _showSnackBar(_l10n.addedTripOutfitsCount(result.generatedCount));
          } else if (mode != TripOutfitGenerateMode.refresh &&
              result.collection.savedCandidates.isNotEmpty) {
            _showSnackBar(
              _l10n.savedCandidatesAvailable(
                result.collection.savedCandidates.length,
              ),
            );
          } else {
            _showSnackBar(_l10n.noMoreTripOutfitCombinations);
          }
        }
        return result.collection;
      },
    );
  }

  Future<bool> _confirmRefresh(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.refreshSuggestionsTitle,
        body: _l10n.refreshSuggestionsBody(count),
        primaryLabel: _l10n.refresh,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _createOutfit() async {
    if (_actionsLocked) return;
    final suitcase = _detail.suitcase.where((g) => !g.isDeleted).toList();
    final garmentIds = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitEditPage(
          preloadedGarments: suitcase,
          validGarmentIds: {
            for (final g in suitcase)
              if (g.id != null) g.id!,
          },
          title: _l10n.createOutfit,
        ),
      ),
    );
    if (garmentIds == null || garmentIds.isEmpty || !mounted) return;
    await runCollectionAction(
      fallback: _l10n.failedToAddTripOutfit,
      request: () => TripService().createTripOutfit(
        _tripId,
        garmentIds: garmentIds.toList(),
      ),
    );
  }

  Future<void> _openOutfit(TripOutfit outfit, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripOutfitDetailPage(
          tripId: _tripId,
          tripOutfitId: outfit.id,
          index: index,
        ),
      ),
    );
  }

  Future<void> _addSavedOutfit(Outfit outfit) async {
    if (_editLegsActionInFlight) return;
    final added = await runCollectionAction(
      fallback: _l10n.failedToAddTripOutfit,
      request: () =>
          TripService().addTripOutfitFromSaved(_tripId, outfitId: outfit.id),
    );
    if (added && mounted) _showSnackBar(_l10n.addedOutfitToTrip);
  }

  /// Lets the user look at (and switch) versions before adding one.
  Future<void> _previewSavedOutfit(Outfit outfit) async {
    if (_actionsLocked) return;
    final version = await Navigator.push<Outfit>(
      context,
      MaterialPageRoute(
        builder: (_) => TripOutfitVersionPage(
          outfit: outfit,
          packedGarmentIds: _detail.suitcaseIds,
          addedOutfitIds: _detail.addedSourceOutfitIds,
        ),
      ),
    );
    if (version != null && mounted) await _addSavedOutfit(version);
  }

  /// Re-fetches the collection for a freshly signed image URL.
  Future<String?> _refreshOutfitImageUrl(int tripOutfitId) async {
    try {
      final collection = await TripService().getTripOutfits(_tripId);
      for (final o in collection.outfits) {
        if (o.id == tripOutfitId) return o.resultImageUrl;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _l10n.tripDetailsTitle,
      showTitle: false,
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
    if (_actionsLocked) return;
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

  /// Optimistic update with rollback. A legs edit changes the trip's days
  /// (the suggested outfit count and saved-outfit weather matching), so the
  /// collection is re-fetched; existing outfits aren't touched.
  Future<void> _updateTrip(Trip updated) async {
    final previous = _trip;
    final legsChanged = !identical(updated.legs, previous.legs);
    setState(() => _trip = updated);
    ref.read(tripsProvider.notifier).updateTrip(updated);
    // The packing analysis is derived from legs/dates/activities.
    ref.invalidate(tripSuggestionProvider(int.parse(previous.id)));
    try {
      // The backend doesn't resize `days` from `legs`, so resend the dates.
      // Temperature is filled in server-side.
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
        await _reloadCollection();
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
    // Helpers read the collection through [_detail].
    ref.watch(tripDetailProvider(_tripId));
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: _buildAppBar(),
          body: ListView(
            padding: EdgeInsets.only(
              bottom: 32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const SizedBox(height: 20),
              _paddedSection(Text(_trip.name, style: AppTextStyle.bold22)),
              const SizedBox(height: AppDimens.titleGap),
              _paddedSection(
                AppCardShell(
                  title: _l10n.itineraryTitle,
                  child: _TripItineraryHeader(trip: _trip),
                ),
              ),
              const SizedBox(height: AppDimens.sectionSpacing),
              _paddedSection(_buildSuitcaseSection()),
              const SizedBox(height: AppDimens.sectionSpacing),
              _paddedSection(_buildOutfitsHeader()),
              const SizedBox(height: AppDimens.sectionSpacing),
              ..._buildOutfitsBody(),
            ],
          ),
        ),
        if (_generatingOutfits)
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

  Widget _buildOutfitsHeader() {
    final detail = _detail;
    final viable = isViableSuitcase(detail.suitcase);
    final locked = _actionsLocked;
    final canAdd = viable;
    final canRefresh = detail.replaceableOutfits.isNotEmpty;
    final showsStatus = detail.totalDays > 0;
    final showsFindMore = detail.outfits.isNotEmpty && viable;
    final showsTextActions = canAdd || canRefresh;
    return AppCardShell(
      title: _l10n.yourTripOutfits,
      child: !showsStatus && !showsFindMore && !showsTextActions
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showsStatus) _buildVarietyStatus(detail),
                if (showsFindMore) ...[
                  if (showsStatus)
                    const AppDivider(spacing: AppDimens.sectionSpacing),
                  ActionButton(
                    label: _l10n.findMoreOutfits,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    onPressed: locked
                        ? null
                        : () => _generateOutfits(TripOutfitGenerateMode.more),
                  ),
                ],
                if (showsTextActions) ...[
                  if (showsStatus || showsFindMore) const SizedBox(height: 4),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (canAdd)
                          _OutfitPlannerTextAction(
                            icon: Icons.add,
                            label: _l10n.addTripOutfit,
                            onPressed: locked ? null : _createOutfit,
                          ),
                        if (canAdd && canRefresh)
                          Container(
                            width: 1,
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: AppColors.borderSubtle,
                          ),
                        if (canRefresh)
                          _OutfitPlannerTextAction(
                            icon: Icons.autorenew,
                            label: _l10n.refreshAiButton,
                            onPressed: locked
                                ? null
                                : () => _generateOutfits(
                                    TripOutfitGenerateMode.refresh,
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Enough outfits for the trip earns the check; below the suggested
  /// minimum it states the range to aim for instead.
  Widget _buildVarietyStatus(TripOutfitCollection detail) {
    final enough =
        detail.outfits.isNotEmpty &&
        detail.outfits.length >= detail.suggestedMin;
    final text = Text(
      enough
          ? _l10n.tripOutfitsGoodVariety(detail.totalDays)
          : _l10n.tripOutfitsSuggestedRange(
              detail.suggestedMin,
              detail.suggestedMax,
              detail.totalDays,
            ),
      style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
    );
    if (!enough) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 20,
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
        Expanded(child: text),
      ],
    );
  }

  List<Widget> _buildOutfitsBody() {
    final detail = _detail;
    final viable = isViableSuitcase(detail.suitcase);
    return [
      _paddedSection(
        LabeledDivider(label: _l10n.tripOutfitsCount(detail.outfits.length)),
      ),
      const SizedBox(height: AppDimens.cardHeaderGap),
      if (detail.outfits.isEmpty)
        _paddedSection(
          viable
              ? EmptyStatePlaceholder(
                  icon: Icons.style_outlined,
                  title: _l10n.letUwearisPlanOutfits,
                  message: _l10n.letUwearisPlanOutfitsHint,
                  actionLabel: _l10n.planTripOutfits,
                  // _generateOutfits guards re-entry itself.
                  onAction: () => _generateOutfits(TripOutfitGenerateMode.plan),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                )
              : EmptyStatePlaceholder(
                  icon: Icons.style_outlined,
                  title: _l10n.tripOutfitsEmptyTitle,
                  message: _l10n.tripOutfitsEmptyHint,
                  actionLabel: _l10n.openSuitcase,
                  onAction: _openSuitcase,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
        )
      else
        _buildOutfitGrid(detail),
      if (detail.savedCandidates.isNotEmpty) ...[
        const SizedBox(height: AppDimens.titleGap),
        _paddedSection(
          SectionHeader(
            title: _l10n.fromYourOutfits,
            subtitle: _l10n.fromYourOutfitsHint,
          ),
        ),
        const SizedBox(height: AppDimens.cardHeaderGap),
        _buildSavedCandidates(detail.savedCandidates),
      ],
    ];
  }

  Widget _buildOutfitGrid(TripOutfitCollection detail) {
    final suitcaseIds = detail.suitcaseIds;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: OutfitGrid.gridDelegate,
      itemCount: detail.outfits.length,
      itemBuilder: (context, i) => TripOutfitTile(
        outfit: detail.outfits[i],
        index: i + 1,
        suitcaseIds: suitcaseIds,
        onTap: () => _openOutfit(detail.outfits[i], i + 1),
        onRefreshImageUrl: () => _refreshOutfitImageUrl(detail.outfits[i].id),
      ),
    );
  }

  static const double _candidateCardWidth = 150;

  Widget _buildSavedCandidates(List<Outfit> candidates) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < candidates.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.cardSpacing),
            SizedBox(
              width: _candidateCardWidth,
              child: Column(
                children: [
                  OutfitCard(
                    outfit: candidates[i],
                    onTap: () => _previewSavedOutfit(candidates[i]),
                  ),
                  const SizedBox(height: 8),
                  AccentPillButton(
                    label: _l10n.addToTrip,
                    onPressed: _actionsLocked
                        ? null
                        : () => _addSavedOutfit(candidates[i]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuitcaseSection() {
    final packedCount = _detail.suitcaseIds.length;
    const leading = Icon(Icons.luggage_outlined, color: AppColors.icon);
    if (packedCount == 0) {
      return AppListCard(
        title: _l10n.suitcaseLabel,
        leading: leading,
        showArrow: true,
        onTap: _openSuitcase,
        child: Text(
          _l10n.packClothingHint,
          style: AppTextStyle.regular12.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return AppListCard(
      leading: leading,
      showArrow: true,
      onTap: _openSuitcase,
      status: _l10n.suitcaseItemsCount(packedCount),
      child: Text(_l10n.suitcaseLabel, style: AppTextStyle.bold16),
    );
  }
}

/// The trip's legs as a timeline: a ring-and-dot marker per stop, joined by
/// a line through every stop but the ends.
class _TripItineraryHeader extends StatelessWidget {
  final Trip trip;

  const _TripItineraryHeader({required this.trip});

  static const double _markerSize = 18;
  static const double _lineWidth = 2;

  @override
  Widget build(BuildContext context) {
    final legs = trip.legs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < legs.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _markerSize,
                  child: Column(
                    children: [
                      Expanded(child: _buildLine(visible: i > 0)),
                      const Icon(
                        Icons.radio_button_checked,
                        size: _markerSize,
                        color: AppColors.accent,
                      ),
                      Expanded(child: _buildLine(visible: i < legs.length - 1)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            legs[i].location.name,
                            style: AppTextStyle.regular16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${DateFormat.MMMd(dateLocaleOf(context)).format(legs[i].dateRange.start)} - "
                          "${DateFormat.MMMd(dateLocaleOf(context)).format(legs[i].dateRange.end)}",
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLine({required bool visible}) {
    return Center(
      child: Container(
        width: _lineWidth,
        color: visible ? AppColors.borderSubtle : Colors.transparent,
      ),
    );
  }
}

/// A low-emphasis Outfit Planner action under its primary button: icon +
/// label in secondary text, full touch target.
class _OutfitPlannerTextAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _OutfitPlannerTextAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? AppColors.hintText
        : AppColors.textSecondary;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      label: Text(label, style: AppTextStyle.medium14.copyWith(color: color)),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppDimens.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: AppColors.textSecondary,
      ),
    );
  }
}
