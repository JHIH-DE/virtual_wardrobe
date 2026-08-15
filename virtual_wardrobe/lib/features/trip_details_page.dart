import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/outfit_service.dart';
import '../core/services/trip_service.dart';
import '../core/utils/debug_log.dart';
import '../core/utils/signed_url.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/garment.dart';
import '../data/outfit.dart';
import '../data/trip.dart';
import '../l10n/generated/app_localizations.dart';
import 'add_outfit_page.dart';
import 'outfit_details_page.dart';
import 'trip_suitcase_page.dart';
import 'widgets/common/overlays/app_dialog.dart';
import 'widgets/common/cards/app_list_card.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/overlays/empty_state_placeholder.dart';
import 'widgets/common/overlays/loading_overlay.dart';
import 'widgets/common/cards/lumi_insight_card.dart';
import 'widgets/trip/today_outfit_idea.dart';
import 'widgets/garment/garment_image.dart';
import 'widgets/trip/trip_day_card.dart';

/// One trip day's primary outfit option, as returned embedded in
/// `TripService.getTrip`'s `days[].options[]` — no separate
/// per-day fetch needed once the trip has been loaded.
class TripDayOutfit {
  final int? optionId;
  final List<Garment> garments;
  final int? outfitId;
  final double? temperatureMaxC;
  final double? temperatureMinC;

  const TripDayOutfit({
    this.optionId,
    this.garments = const [],
    this.outfitId,
    this.temperatureMaxC,
    this.temperatureMinC,
  });
}

class TripDetailsInitialData {
  final List<TripDayOutfit> dayOutfits;
  final Set<int> suitcaseIds;

  const TripDetailsInitialData({
    required this.dayOutfits,
    required this.suitcaseIds,
  });
}

/// Parses `suitcase_items` from a `getTrip` response — items may come back
/// either as `{garment_id: int, ...}` objects or bare ints.
Set<int> _parseSuitcaseItemIds(dynamic rawItems) {
  final ids = <int>{};
  if (rawItems is List) {
    for (final item in rawItems) {
      if (item is Map && item['garment_id'] is int) {
        ids.add(item['garment_id'] as int);
      } else if (item is int) {
        ids.add(item);
      }
    }
  }
  return ids;
}

/// Picks the primary (lowest `order_index`) outfit option for one trip day.
/// Each item's `image_url`/`category`/`name` now come back embedded
/// directly (`TripOutfitItemResponse`), so garments are built straight from
/// them — no separate closet fetch needed to resolve `garment_id`s. The
/// day's temperature range comes straight from the trip plan itself
/// (`temperature_max_c` / `temperature_min_c`), not a separate weather fetch.
TripDayOutfit _parseTripDayOutfit(Map<String, dynamic> day) {
  final temperatureMaxC = (day['temperature_max_c'] as num?)?.toDouble();
  final temperatureMinC = (day['temperature_min_c'] as num?)?.toDouble();
  final options =
      ((day['options'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort(
          (a, b) => ((a['order_index'] as num?) ?? 0).compareTo(
            (b['order_index'] as num?) ?? 0,
          ),
        );
  if (options.isEmpty) {
    return TripDayOutfit(
      temperatureMaxC: temperatureMaxC,
      temperatureMinC: temperatureMinC,
    );
  }

  final primary = options.first;
  final items = ((primary['items'] as List?) ?? [])
      .whereType<Map<String, dynamic>>();
  final garments = items.map(Garment.fromTripItemJson).toList();

  return TripDayOutfit(
    optionId: (primary['id'] as num?)?.toInt(),
    garments: garments,
    outfitId: (primary['outfit_id'] as num?)?.toInt(),
    temperatureMaxC: temperatureMaxC,
    temperatureMinC: temperatureMinC,
  );
}

class TripDetailsPage extends ConsumerStatefulWidget {
  final Trip trip;
  final TripDetailsInitialData initialData;

  const TripDetailsPage({
    super.key,
    required this.trip,
    required this.initialData,
  });

  /// Fetches everything [TripDetailsPage] needs up front, so the page can be
  /// pushed only once loading is complete (no in-page spinner on open).
  static Future<TripDetailsInitialData> preload(Trip trip) async {
    List<TripDayOutfit> dayOutfits = [];
    Set<int> suitcaseIds = {};
    try {
      final tripData = await TripService().getTrip(int.parse(trip.id));
      final rawDays = (tripData['days'] as List?) ?? [];
      dayOutfits = rawDays
          .whereType<Map<String, dynamic>>()
          .map(_parseTripDayOutfit)
          .toList();
      suitcaseIds = _parseSuitcaseItemIds(tripData['suitcase_items']);
    } catch (e) {
      if (e is AuthExpiredException) rethrow;
      debugLog('Failed to load trip outfits: $e');
    }

    return TripDetailsInitialData(
      dayOutfits: dayOutfits,
      suitcaseIds: suitcaseIds,
    );
  }

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage>
    with TryOnMixin {
  // TripDayCard's own width plus the gap around it — the per-page slot
  // width used to size the day selector's PageController.viewportFraction.
  static const double _dayCardWidth = 95;
  static const double _dayCardGap = 8;

  int _selectedDayIndex = 0;
  PageController? _dayPageController;

  late List<TripDayOutfit> _dayOutfits = widget.initialData.dayOutfits;
  late Set<int> _suitcaseIds = widget.initialData.suitcaseIds;

  /// Once a day's try-on job has resolved to an image URL, it's kept here
  /// so switching away and back to that day — or leaving this page and
  /// coming back to a brand new [TripDetailsPage] instance entirely —
  /// shows it straight away instead of re-polling `getOutfit` for a job
  /// that's already finished. Static (rather than an instance field) so it
  /// outlives any single page instance for the rest of the app session.
  /// This exists *in addition to* [TodayOutfitIdea.cacheKey]: that keeps
  /// the actual image bytes on disk keyed by job id (survives even app
  /// restarts), while this map avoids the redundant `getOutfit` network
  /// call itself, since the backend hands back a freshly re-signed URL —
  /// and therefore a disk-cache miss on the URL string alone — every time.
  static final Map<int, String> _resolvedOutfitImageUrls = {};

  /// The last successfully-shown image for the *current* day, kept
  /// separate from [tryOnResultUrl] (which `TryOnMixin` nulls out the
  /// moment a poll/regenerate starts) so [TodayOutfitIdea] can keep
  /// showing it — with a loading overlay on top — while a regenerate is in
  /// flight, the same way Outfit Details overlays a loading state on a
  /// look's existing image instead of blanking it out. Cleared on day
  /// switches (a different day's photo shouldn't linger under the
  /// spinner), but deliberately *not* cleared when a regenerate starts.
  String? _lastShownOutfitImageUrl;

  bool _loadingPackingAdvice = false;
  String? _packingAdvice;
  bool _packingAdviceExpanded = false;
  int? _recommendedTotal;
  bool _generatingPlan = false;
  bool _loadingEditor = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  TripDayOutfit? get _currentDayOutfit => _selectedDayIndex < _dayOutfits.length
      ? _dayOutfits[_selectedDayIndex]
      : null;

  List<Garment> get _todayGarments => _currentDayOutfit?.garments ?? const [];

  /// True if any of today's outfit garments have since been removed from
  /// the trip's suitcase — e.g. the user unpacked something after LUMI (or
  /// the user themself) already assigned it to this day.
  bool get _hasMissingSuitcaseItems =>
      _todayGarments.any((g) => g.id != null && !_suitcaseIds.contains(g.id));

  @override
  void initState() {
    super.initState();
    _loadPackingAdvice();
    _loadOutfitImage();
    // preload() fetched fresh garment image URLs, but if this page instance
    // stays open long enough for them to expire (e.g. backgrounded, or the
    // trip was preloaded a while before the user actually opened it), there
    // was previously no way to recover — the day outfits were immutable.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureFreshDayGarments(),
    );
  }

  @override
  void dispose() {
    _dayPageController?.dispose();
    super.dispose();
  }

  Future<void> _loadOutfitImage() async {
    final outfitId = _currentDayOutfit?.outfitId;
    if (outfitId == null || outfitId == 0) return;

    final cachedUrl = _resolvedOutfitImageUrls[outfitId];
    if (cachedUrl != null) {
      if (mounted) {
        setState(() {
          tryOnOutfitId = outfitId;
          tryOnResultUrl = cachedUrl;
          _lastShownOutfitImageUrl = cachedUrl;
        });
      }
      return;
    }

    final resolvedOutfitId = await watchJob(outfitId);
    if (resolvedOutfitId != null && tryOnResultUrl != null) {
      _resolvedOutfitImageUrls[resolvedOutfitId] = tryOnResultUrl!;
      if (mounted) setState(() => _lastShownOutfitImageUrl = tryOnResultUrl);
    }
  }

  bool get _hasStaleGarmentImages => _dayOutfits.any(
    (day) => day.garments.any((g) {
      final url = g.imageUrl;
      return url != null && url.isNotEmpty && isSignedUrlExpired(url);
    }),
  );

  /// Day-option images now come straight from the trip itself
  /// (`TripOutfitItemResponse.image_url`), so refreshing a stale one means
  /// re-fetching the trip, not the closet.
  Future<void> _ensureFreshDayGarments() async {
    if (!_hasStaleGarmentImages) return;
    try {
      final tripData = await TripService().getTrip(int.parse(widget.trip.id));
      final rawDays = (tripData['days'] as List?) ?? [];
      final dayOutfits = rawDays
          .whereType<Map<String, dynamic>>()
          .map(_parseTripDayOutfit)
          .toList();
      if (!mounted) return;
      setState(() => _dayOutfits = dayOutfits);
    } catch (_) {
      // Leave the existing URLs; GarmentImage's errorWidget covers the
      // fallback if they've truly expired.
    }
  }

  Future<void> _loadPackingAdvice() async {
    setState(() => _loadingPackingAdvice = true);
    try {
      final data = await TripService().getTripSuggestion(
        int.parse(widget.trip.id),
      );
      if (mounted) {
        setState(() {
          _packingAdvice = data['overall_advice'] as String?;
          _recommendedTotal = _sumRecommendedQuantity(data['categories']);
        });
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to analyze trip plan: $e');
    } finally {
      if (mounted) setState(() => _loadingPackingAdvice = false);
    }
  }

  /// Sums `recommended_quantity` across every category in a
  /// `getTripSuggestion` response, for the Suitcase card's packed/recommended
  /// progress summary.
  int? _sumRecommendedQuantity(dynamic categories) {
    if (categories is! List) return null;
    var total = 0;
    for (final item in categories) {
      if (item is Map && item['recommended_quantity'] is num) {
        total += (item['recommended_quantity'] as num).toInt();
      }
    }
    return total;
  }

  Future<void> _loadDailyData() async {
    resetTryOnState();
    setState(() => _lastShownOutfitImageUrl = null);
    await _loadOutfitImage();
  }

  /// Re-fetches the trip's `days[].options[]` (e.g. after generating or
  /// hand-editing a plan) without re-fetching weather.
  Future<void> _refreshDayOutfits() async {
    final tripData = await TripService().getTrip(int.parse(widget.trip.id));
    final rawDays = (tripData['days'] as List?) ?? [];
    final dayOutfits = rawDays
        .whereType<Map<String, dynamic>>()
        .map(_parseTripDayOutfit)
        .toList();
    if (!mounted) return;
    setState(() {
      _dayOutfits = dayOutfits;
      _suitcaseIds = _parseSuitcaseItemIds(tripData['suitcase_items']);
    });
    await _loadOutfitImage();
  }

  /// Fetches the trip's current suitcase, resolved to full [Garment]
  /// objects straight from each item's own embedded `image_url`/`category`/
  /// `name` fields (`TripSuitcaseItemResponse`) — no closet fetch needed —
  /// and syncs [_suitcaseIds] along the way. Returns null (after showing an
  /// error) if the fetch fails.
  Future<List<Garment>?> _fetchSuitcaseGarments() async {
    try {
      final tripData = await TripService().getTrip(int.parse(widget.trip.id));
      final rawSuitcaseItems = (tripData['suitcase_items'] as List?) ?? [];
      final suitcase = rawSuitcaseItems
          .whereType<Map<String, dynamic>>()
          .map(Garment.fromTripItemJson)
          .toList();
      if (mounted) {
        setState(
          () =>
              _suitcaseIds = _parseSuitcaseItemIds(tripData['suitcase_items']),
        );
      }
      return suitcase;
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return null;
      }
      debugLog('Failed to load suitcase: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateDayOutfit)));
      }
      return null;
    }
  }

  /// A suitcase needs at least one upper-body piece (top or one-piece) and
  /// one lower-body piece (bottom or one-piece) for LUMI to have any chance
  /// of assembling a complete outfit.
  bool _hasViableSuitcase(List<Garment> suitcase) {
    final categories = suitcase.map((g) => g.category).toSet();
    final hasUpper =
        categories.contains(GarmentCategory.top) ||
        categories.contains(GarmentCategory.onePiece);
    final hasLower =
        categories.contains(GarmentCategory.bottom) ||
        categories.contains(GarmentCategory.onePiece);
    return hasUpper && hasLower;
  }

  Future<void> _openSuitcase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: widget.trip)),
    );
    if (!mounted) return;
    await _fetchSuitcaseGarments();
  }

  /// Asks LUMI to build an outfit for every day of the trip from whatever's
  /// currently packed in the suitcase. Confirms first if a plan already
  /// exists, since this replaces every day's outfit — including any the
  /// user adjusted by hand.
  Future<void> _generatePlan() async {
    final fetched = await _fetchSuitcaseGarments();
    if (fetched == null || !mounted) return;

    if (!_hasViableSuitcase(fetched)) {
      final goToSuitcase = await showDialog<bool>(
        context: context,
        builder: (ctx) => AppDialog(
          title: _l10n.insufficientSuitcaseTitle,
          body: _l10n.insufficientSuitcaseBody,
          primaryLabel: _l10n.goToSuitcase,
          onPrimary: () => Navigator.pop(ctx, true),
          secondaryLabel: _l10n.cancel,
          onSecondary: () => Navigator.pop(ctx, false),
        ),
      );
      if (goToSuitcase == true && mounted) await _openSuitcase();
      return;
    }

    final hasExistingPlan = _dayOutfits.any((d) => d.optionId != null);
    if (hasExistingPlan) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AppDialog(
          title: _l10n.regeneratePlanTitle,
          body: _l10n.regeneratePlanBody,
          primaryLabel: _l10n.regenerate,
          onPrimary: () => Navigator.pop(ctx, true),
          secondaryLabel: _l10n.cancel,
          onSecondary: () => Navigator.pop(ctx, false),
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;

    setState(() => _generatingPlan = true);
    try {
      await TripService().generateTripPlan(int.parse(widget.trip.id));
      await _refreshDayOutfits();
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to generate trip plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToGeneratePlan)));
      }
    } finally {
      if (mounted) setState(() => _generatingPlan = false);
    }
  }

  /// Lets the user manually swap which suitcase garments make up the
  /// selected day's outfit, reusing [AddOutfitPage]'s per-category slot
  /// picker. Only reachable once LUMI has generated a plan (there has to be
  /// an existing option to PATCH).
  Future<void> _openDayOutfitEditor() async {
    final optionId = _currentDayOutfit?.optionId;
    if (optionId == null) return;

    setState(() => _loadingEditor = true);
    final fetched = await _fetchSuitcaseGarments();
    if (mounted) setState(() => _loadingEditor = false);
    if (fetched == null || !mounted) return;
    final suitcaseGarments = fetched;

    final validIds = Set.of(_suitcaseIds);

    final result = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddOutfitPage(
          initialGarments: _todayGarments,
          preloadedGarments: suitcaseGarments,
          selectOnly: true,
          validGarmentIds: validIds,
        ),
      ),
    );
    if (result == null || !mounted) return;

    try {
      final updated = await TripService().updateOptionItems(
        int.parse(widget.trip.id),
        optionId: optionId,
        garmentIds: result.toList(),
      );
      final items = (updated['items'] as List?) ?? [];
      final newGarments = items
          .whereType<Map<String, dynamic>>()
          .map(Garment.fromTripItemJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _dayOutfits[_selectedDayIndex] = TripDayOutfit(
          optionId: optionId,
          outfitId: _currentDayOutfit?.outfitId,
          temperatureMaxC: _currentDayOutfit?.temperatureMaxC,
          temperatureMinC: _currentDayOutfit?.temperatureMinC,
          garments: newGarments,
        );
      });
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
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
        await TripService().addSuitcaseItem(
          int.parse(widget.trip.id),
          garmentId: id,
        );
      }
      if (!mounted) return;
      setState(() => _suitcaseIds.addAll(missingIds));
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
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
      title: widget.trip.name,
      actions: [
        IconButton(
          onPressed: _generatingPlan ? null : _generatePlan,
          icon: const Icon(Icons.auto_awesome_outlined, color: AppColors.icon),
        ),
      ],
    );
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
          // screen — including the trip header/insight/suitcase/day-selector
          // area — scrolls the whole page, not just the section below them.
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 20),
              _paddedSection(_buildTripHeader()),
              const SizedBox(height: 20),
              _paddedSection(_buildLumiInsightCard()),
              const SizedBox(height: 20),
              _paddedSection(_buildSuitcaseSection()),
              const SizedBox(height: 20),
              _paddedSection(_buildDayPlanCard()),
            ],
          ),
        ),
        if (_generatingPlan)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingPlanEllipsis),
          ),
        if (_loadingEditor)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingSuitcaseEllipsis),
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
            child: Text(_l10n.dailyOutfitPlan, style: AppTextStyle.bold18),
          ),
          const SizedBox(height: 8),
          _buildTripDaySelector(),
          const SizedBox(height: 12),
          _paddedSection(_buildOutfitDateHeader()),
          const SizedBox(height: 12),
          _paddedSection(_buildOutfitSection()),
          const SizedBox(height: 16),
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
    final date = widget.trip.dateRange.start.add(
      Duration(days: _selectedDayIndex),
    );
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
              child: Text(
                _l10n.outfitForDate(dateStr),
                style: AppTextStyle.bold16,
              ),
            ),
            if (hasOption)
              IconButton(
                onPressed: _openDayOutfitEditor,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.icon,
                ),
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

  Widget _buildOutfitSection() {
    return TodayOutfitIdea(
      onTap: _openOutfitDetails,
      onGenerate: _handleGenerateOutfit,
      // The last successfully-shown image, not the raw (nulled-out-while-
      // loading) tryOnResultUrl — lets the widget keep it visible with a
      // loading overlay on top while regenerating, instead of blanking out.
      imageUrl: _lastShownOutfitImageUrl,
      isLoading: isOutfitLoading,
      jobStatus: isOutfitLoading
          ? (tryOnOutfitId == 0
                ? _l10n.creatingEllipsis
                : _l10n.generatingEllipsis)
          : null,
      errorMessage: tryOnErrorMessage,
      onRefreshUrl: _refreshOutfitImageUrl,
      cacheKey: tryOnOutfitId != 0 ? 'outfit-job-$tryOnOutfitId' : null,
    );
  }

  /// Re-fetches the current day's already-completed try-on job to pick up
  /// a freshly-signed `result_image_url` if the cached one expired —
  /// there's no new job to create, just the same one's latest status.
  Future<String?> _refreshOutfitImageUrl() async {
    final outfitId = tryOnOutfitId != 0
        ? tryOnOutfitId
        : _currentDayOutfit?.outfitId;
    if (outfitId == null || outfitId == 0) return null;
    try {
      final result = await OutfitService().getOutfit(outfitId);
      final url =
          (primaryLookOf(result)?['result_image_url'] ??
                  result['result_image_url'])
              as String?;
      if (url != null) _resolvedOutfitImageUrls[outfitId] = url;
      return url;
    } catch (e) {
      debugLog('Failed to refresh outfit image url: $e');
      return null;
    }
  }

  Widget _buildTripHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.trip.legs.length; i++) ...[
            if (i > 0) _buildLegDivider(),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.trip.legs[i].location.name,
                    style: AppTextStyle.bold16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${DateFormat('MMM d').format(widget.trip.legs[i].dateRange.start)} - "
                  "${DateFormat('MMM d').format(widget.trip.legs[i].dateRange.end)}",
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Divider(height: 1, thickness: 1, color: AppColors.dividerStrong),
    );
  }

  /// A centered, swipe-only day carousel — the day centered in the
  /// viewport is always the selected one (no tapping a card to select it).
  Widget _buildTripDaySelector() {
    final int totalDays = widget.trip.dateRange.duration.inDays + 1;
    return _fadeHorizontalEdges(
      SizedBox(
        height: 102,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = _dayCardWidth + _dayCardGap;
            final fraction = (slotWidth / constraints.maxWidth).clamp(
              0.05,
              1.0,
            );
            _dayPageController ??= PageController(
              viewportFraction: fraction,
              initialPage: _selectedDayIndex,
            );
            return PageView.builder(
              controller: _dayPageController,
              itemCount: totalDays,
              onPageChanged: _selectDay,
              itemBuilder: (context, index) {
                final date = widget.trip.dateRange.start.add(
                  Duration(days: index),
                );
                final dayOutfit = index < _dayOutfits.length
                    ? _dayOutfits[index]
                    : null;
                return Center(
                  child: TripDayCard(
                    date: date,
                    isSelected: index == _selectedDayIndex,
                    temperatureMaxC: dayOutfit?.temperatureMaxC,
                    temperatureMinC: dayOutfit?.temperatureMinC,
                    onTap: () => _dayPageController?.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _selectDay(int index) {
    setState(() => _selectedDayIndex = index);
    _loadDailyData();
  }

  TripLeg? _legForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    for (final leg in widget.trip.legs) {
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

  /// Fades a horizontally-scrolling child out near its left/right edges, so
  /// content sliding past doesn't end abruptly at the card's border. Uses a
  /// same-color scrim overlay (matching the card background) rather than a
  /// ShaderMask blend — blending against the list's own colors made the
  /// fade look washed out / flash white during scroll.
  Widget _fadeHorizontalEdges(Widget child) {
    Widget scrim(Alignment begin, Alignment end) {
      return IgnorePointer(
        child: Container(
          width: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                AppColors.surface,
                AppColors.surface.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: scrim(Alignment.centerLeft, Alignment.centerRight),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: scrim(Alignment.centerRight, Alignment.centerLeft),
        ),
      ],
    );
  }

  Widget _buildWardrobeSection() {
    final hasOption = _currentDayOutfit?.optionId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_todayGarments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: hasOption
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
                : _buildGeneratePlanCta(),
          )
        else ...[
          _fadeHorizontalEdges(
            SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _todayGarments.length,
                itemBuilder: (context, index) =>
                    _buildGarmentItem(_todayGarments[index]),
              ),
            ),
          ),
          if (_hasMissingSuitcaseItems) ...[
            const SizedBox(height: 16),
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
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.missingFromSuitcaseCount(missingCount),
            style: AppTextStyle.regular13.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _fixMissingSuitcaseItems,
              child: Text(
                _l10n.addToSuitcase,
                style: AppTextStyle.semibold14.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratePlanCta() {
    return GestureDetector(
      onTap: _generatingPlan ? null : _generatePlan,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 28),
            const SizedBox(height: 8),
            Text(_l10n.letLumiPlanOutfits, style: AppTextStyle.bold14),
            const SizedBox(height: 4),
            Text(
              _l10n.letLumiPlanOutfitsHint,
              textAlign: TextAlign.center,
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLumiInsightCard() {
    if (!_loadingPackingAdvice &&
        (_packingAdvice == null || _packingAdvice!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return LumiInsightCard(
      child: _loadingPackingAdvice
          ? Row(
              children: [
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  _l10n.thinkingEllipsis,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(
                () => _packingAdviceExpanded = !_packingAdviceExpanded,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _l10n.tapToViewAiSummary,
                          style: AppTextStyle.bold14,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _packingAdviceExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppColors.icon,
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 150),
                    crossFadeState: _packingAdviceExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _packingAdvice!,
                        style: AppTextStyle.regular14.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ],
              ),
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

  Widget _buildGarmentItem(Garment g) {
    final isMissing = g.id != null && !_suitcaseIds.contains(g.id);
    return Container(
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
            child: GarmentImage(
              url: g.imageUrl,
              garmentId: g.id,
              memCacheWidth: 160,
              fit: BoxFit.cover,
              borderRadius: 12,
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
    );
  }

  Future<void> _handleGenerateOutfit() async {
    if (_todayGarments.isEmpty) return;
    final optionId = _currentDayOutfit?.optionId;
    if (optionId == null) return;

    final ids = _todayGarments
        .where((g) => g.id != null)
        .map((g) => g.id!)
        .toList();
    final int? outfitId = await performTryOn(ids, "trip");

    if (outfitId == null) {
      // With a previous image still on screen, TodayOutfitIdea no longer
      // blanks out to its inline error view on failure (matching Outfit
      // Details, which leaves a look's existing image in place) — so a
      // failed regenerate needs its own explicit surface.
      if (mounted &&
          _lastShownOutfitImageUrl != null &&
          tryOnErrorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tryOnErrorMessage!)));
      }
      return;
    }

    if (tryOnResultUrl != null) {
      _resolvedOutfitImageUrls[outfitId] = tryOnResultUrl!;
      if (mounted) setState(() => _lastShownOutfitImageUrl = tryOnResultUrl);
    }
    try {
      await TripService().setTryonJobToOption(
        outfitId,
        optionId: optionId,
        tripId: int.parse(widget.trip.id),
      );
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to save outfitId: $e');
    }
  }

  void _openOutfitDetails() {
    final url = tryOnResultUrl;
    if (url == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitDetailsPage(
          outfit: Outfit(
            id: tryOnOutfitId,
            imageUrl: url,
            advice: tryOnAiAdvice,
            garmentIds: _todayGarments
                .where((g) => g.id != null)
                .map((g) => g.id!)
                .toList(),
          ),
          isNew: true,
          confirmLeaveOnBack: false,
          navigateToOutfitsTabOnSave: false,
          showEditOutfitWhenSaved: false,
        ),
      ),
    );
  }
}
