import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/trips_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/signed_url.dart';
import '../../data/garment.dart';
import '../../data/trip.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/trip_activity_localization.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/edge_fade_scrim.dart';
import '../widgets/common/expandable_insight_body.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_image.dart';
import '../widgets/trip/today_outfit_idea.dart';
import '../widgets/trip/trip_day_card.dart';
import '../widgets/trip/trip_legs_editor.dart';
import 'add_outfit_page.dart';
import 'trip_suitcase_page.dart';

/// Actions in [TripDetailsPage]'s app bar "⋮" menu — moved here from
/// [TripCard] (the Trips-tab list item) so a trip's own metadata edits live
/// on its detail page instead of duplicated across every card that links
/// to it.
enum _TripMenuAction {
  editName,
  editLegs,
  editActivities,
  regeneratePlan,
  delete,
}

/// One trip day's primary outfit — either an *already tried-on* result
/// (built from `TripService.getTrip`'s `days[].outfits[]`, see
/// [_parseTripDayOutfit]) or an AI-suggested option nobody's rendered yet
/// (built from `TripService.getTripPlan`/`generateTripPlan`'s
/// `days[].options[]`, see [_parseGeneratedTripDayOutfit]) — both parse
/// into this same shape so the rest of the page doesn't need to care which
/// one a given day came from.
class TripDayOutfit {
  /// This day's own date, straight from `day['date']` — the day selector
  /// and header label read this instead of computing a date from the
  /// trip's overall span + list index, since the backend's `days[]` isn't
  /// guaranteed to tile that span with zero gaps (e.g. multi-leg trips
  /// with a stretch between legs covered by no leg at all).
  final DateTime? date;
  final int? optionId;
  final List<Garment> garments;
  final int? outfitId;
  final String? resultImageUrl;
  final double? temperatureMaxC;
  final double? temperatureMinC;

  /// Sticky across garment edits — unlike [outfitId] (which the backend
  /// clears the moment this day's garments change, see
  /// `TripService.updateOptionItems`), this never resets once true. Its
  /// only job is telling "Generate Outfit" (never rendered before) apart
  /// from "Regenerate Outfit" (this slot had an image once; the garments
  /// backing it just changed since) — see
  /// [_TripDetailsPageState._primaryAction].
  final bool everHadOutfit;

  const TripDayOutfit({
    this.date,
    this.optionId,
    this.garments = const [],
    this.outfitId,
    this.resultImageUrl,
    this.temperatureMaxC,
    this.temperatureMinC,
    this.everHadOutfit = false,
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

/// The page's single "what's the next step" CTA — see
/// [_TripDetailsPageState._primaryAction]. Never more than one of these is
/// active at once, by construction: [generateOutfit]/[regenerateOutfit] are
/// per-day and only ever apply once a non-stale trip plan already exists.
enum TripGenerationAction {
  generateTripPlan,
  generateOutfit,
  regenerateOutfit,
  none,
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

/// Picks the primary already-tried-on outfit for one trip day out of
/// `day['outfits']` — unlike the old `options[].items[]` shape, an entry
/// here only carries `garment_ids` (no embedded image/name/category), so
/// [closetGarments] (the user's full closet, not just the suitcase — a
/// garment can be unpacked from the suitcase after being tried on, see
/// `_hasMissingSuitcaseItems`) is used to resolve them. The day's
/// temperature range comes straight from the trip plan itself
/// (`temperature_max_c` / `temperature_min_c`), not a separate weather fetch.
TripDayOutfit _parseTripDayOutfit(
  Map<String, dynamic> day,
  List<Garment> closetGarments,
) {
  final date = DateTime.tryParse((day['date'] as String?) ?? '');
  final temperatureMaxC = (day['temperature_max_c'] as num?)?.toDouble();
  final temperatureMinC = (day['temperature_min_c'] as num?)?.toDouble();
  final outfits = ((day['outfits'] as List?) ?? [])
      .whereType<Map<String, dynamic>>()
      .toList();
  if (outfits.isEmpty) {
    return TripDayOutfit(
      date: date,
      temperatureMaxC: temperatureMaxC,
      temperatureMinC: temperatureMinC,
    );
  }

  final primary = outfits.firstWhere(
    (o) => o['option_type'] == 'primary',
    orElse: () => outfits.first,
  );
  final garmentIds = ((primary['garment_ids'] as List?) ?? [])
      .whereType<num>()
      .map((n) => n.toInt());
  final closetById = {
    for (final g in closetGarments)
      if (g.id != null) g.id!: g,
  };
  final garments = garmentIds
      .map((id) => closetById[id])
      .whereType<Garment>()
      .toList();
  final outfitId = (primary['outfit_id'] as num?)?.toInt();

  return TripDayOutfit(
    date: date,
    optionId: (primary['trip_option_id'] as num?)?.toInt(),
    garments: garments,
    outfitId: outfitId,
    resultImageUrl: primary['result_image_url'] as String?,
    temperatureMaxC: temperatureMaxC,
    temperatureMinC: temperatureMinC,
    everHadOutfit: outfitId != null,
  );
}

/// Picks the primary (lowest `order_index`) suggested option for one trip
/// day out of `POST /generate`'s own `day['options']` — unlike
/// [_parseTripDayOutfit] (which reads already-tried-on results from `GET
/// /trip_plans/{id}`), this is the *only* place an untried suggestion's
/// garments are ever available, so `_generatePlan` must parse this
/// response directly instead of re-fetching the trip afterward. Each
/// option's items still come back with `image_url`/`category`/`name`
/// embedded (`TripOutfitItemResponse`) — this endpoint's shape hasn't
/// changed, so no closet lookup is needed here.
TripDayOutfit _parseGeneratedTripDayOutfit(Map<String, dynamic> day) {
  final date = DateTime.tryParse((day['date'] as String?) ?? '');
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
      date: date,
      temperatureMaxC: temperatureMaxC,
      temperatureMinC: temperatureMinC,
    );
  }

  final primary = options.first;
  final items = ((primary['items'] as List?) ?? [])
      .whereType<Map<String, dynamic>>();
  final garments = items.map(Garment.fromTripItemJson).toList();
  final outfitId = (primary['outfit_id'] as num?)?.toInt();

  return TripDayOutfit(
    date: date,
    optionId: (primary['id'] as num?)?.toInt(),
    garments: garments,
    outfitId: outfitId,
    resultImageUrl: primary['result_image_url'] as String?,
    temperatureMaxC: temperatureMaxC,
    temperatureMinC: temperatureMinC,
    everHadOutfit: outfitId != null,
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
  ///
  /// Uses `getTripPlan` (`GET /{trip_id}/plan`), not `getTrip` — the latter
  /// only reports days with an already-rendered outfit, so a plan that's
  /// been generated (`POST /generate`) but never rendered into an image
  /// would come back looking exactly like no plan exists at all. `/plan`'s
  /// `days[].options[]` covers both cases (rendered options still carry
  /// their `outfit_id`/`result_image_url`), same shape [_generatePlan]
  /// already parses via [_parseGeneratedTripDayOutfit] — no closet lookup
  /// needed since each option's items embed their own image/name/category.
  static Future<TripDetailsInitialData> preload(Trip trip) async {
    List<TripDayOutfit> dayOutfits = [];
    Set<int> suitcaseIds = {};
    try {
      final planData = await TripService().getTripPlan(int.parse(trip.id));
      final rawDays = (planData['days'] as List?) ?? [];
      dayOutfits = rawDays
          .whereType<Map<String, dynamic>>()
          .map(_parseGeneratedTripDayOutfit)
          .toList();
      suitcaseIds = _parseSuitcaseItemIds(planData['suitcase_items']);
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
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

class _TripDetailsPageState extends ConsumerState<TripDetailsPage> {
  // TripDayCard's own width plus the gap between cards — used to compute
  // how far to scroll the day selector to bring a tapped card into view.
  static const double _dayCardWidth = 95;
  static const double _dayCardGap = 8;

  int _selectedDayIndex = 0;
  final ScrollController _dayScrollController = ScrollController();

  // Mutable local copy — the app bar's edit menu (name/destinations/
  // activities) needs to update what's on screen immediately, and
  // [widget.trip] is otherwise a fixed snapshot from whoever pushed this
  // page. Kept in sync with [tripsProvider] by [_updateTrip].
  late Trip _trip = widget.trip;

  late List<TripDayOutfit> _dayOutfits = widget.initialData.dayOutfits;
  late Set<int> _suitcaseIds = widget.initialData.suitcaseIds;

  bool _loadingPackingAdvice = false;
  String? _packingAdvice;
  bool _packingAdviceExpanded = false;
  int? _recommendedTotal;
  bool _generatingPlan = false;
  bool _generatingOutfit = false;
  bool _loadingEditor = false;

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
  /// the check [_generatePlan] already used to decide whether to confirm
  /// before overwriting.
  bool get _hasTripPlan => _dayOutfits.any((d) => d.optionId != null);

  /// True once a not-yet-rendered day's assignment leans on a garment no
  /// longer in the suitcase — generating that day's outfit would try on
  /// something that isn't packed anymore. Deliberately narrower than "any
  /// missing item anywhere": a day that's *already* been rendered keeps its
  /// image regardless (that garment really was packed when it was made —
  /// see [_hasMissingSuitcaseItems]/[_fixMissingSuitcaseItems] for that
  /// day-local, non-destructive warning), so unpacking something after the
  /// fact doesn't nuke the whole trip plan.
  bool get _isTripPlanStale => _dayOutfits.any(
    (d) =>
        d.optionId != null &&
        d.outfitId == null &&
        d.garments.any((g) => g.id != null && !_suitcaseIds.contains(g.id)),
  );

  /// The one primary CTA this page should show right now — see
  /// [TripGenerationAction]. Order matters: a missing/stale plan always
  /// wins over anything day-specific, since day-level actions only make
  /// sense once the plan under them is trustworthy.
  TripGenerationAction get _primaryAction {
    if (!_hasTripPlan || _isTripPlanStale) {
      return TripGenerationAction.generateTripPlan;
    }
    final day = _currentDayOutfit;
    if (day?.optionId == null) return TripGenerationAction.none;
    if (day!.outfitId != null) return TripGenerationAction.none;
    return day.everHadOutfit
        ? TripGenerationAction.regenerateOutfit
        : TripGenerationAction.generateOutfit;
  }

  @override
  void initState() {
    super.initState();
    _loadPackingAdvice();
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
    _dayScrollController.dispose();
    super.dispose();
  }

  bool get _hasStaleGarmentImages => _dayOutfits.any(
    (day) => day.garments.any((g) {
      final url = g.imageUrl;
      return url != null && url.isNotEmpty && isSignedUrlExpired(url);
    }),
  );

  /// Day outfit garments are resolved against the closet (see
  /// [_parseTripDayOutfit]), so refreshing a stale image URL means
  /// re-fetching both the trip and the closet.
  Future<void> _ensureFreshDayGarments() async {
    if (!_hasStaleGarmentImages) return;
    try {
      final tripData = await TripService().getTrip(int.parse(_trip.id));
      final closetGarments = await GarmentService().getGarments();
      final rawDays = (tripData['days'] as List?) ?? [];
      final dayOutfits = rawDays
          .whereType<Map<String, dynamic>>()
          .map((day) => _parseTripDayOutfit(day, closetGarments))
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
      final data = await TripService().getTripSuggestion(int.parse(_trip.id));
      if (mounted) {
        setState(() {
          _packingAdvice = data['overall_advice'] as String?;
          _recommendedTotal = _sumRecommendedQuantity(data['categories']);
        });
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      if (!mounted) return;
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
          () =>
              _suitcaseIds = _parseSuitcaseItemIds(tripData['suitcase_items']),
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

  /// A suitcase needs at least one upper-body piece (top or one-piece) and
  /// one lower-body piece (bottom or one-piece) for Uwearis to have any chance
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
      MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip)),
    );
    if (!mounted) return;
    await _fetchSuitcaseGarments();
  }

  /// Asks Uwearis to build an outfit for every day of the trip from whatever's
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

    if (_hasTripPlan) {
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
      // Parsed straight from this response, not re-fetched via getTrip —
      // GET only ever reports already-tried-on outfits, so a plain
      // refresh right after generating would just show every day as empty.
      // No UI browses alternatives (_parseGeneratedTripDayOutfit only ever
      // uses the primary option) — ask for none explicitly, since the
      // backend now defaults to generating up to 2 unused ones per day.
      final planData = await TripService().generateTripPlan(
        int.parse(_trip.id),
        alternativesPerDay: 0,
      );
      final rawDays = (planData['days'] as List?) ?? [];
      final dayOutfits = rawDays
          .whereType<Map<String, dynamic>>()
          .map(_parseGeneratedTripDayOutfit)
          .toList();
      if (!mounted) return;
      setState(() => _dayOutfits = dayOutfits);
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
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

  /// Synchronously renders the *currently selected* day's option into a
  /// try-on image — this is [TripGenerationAction.generateOutfit]/
  /// [TripGenerationAction.regenerateOutfit]'s handler, reachable from
  /// either the bottom CTA or the outfit card's "⋮" menu once it already
  /// has an image. Branches on whether this option already has an
  /// `outfit_id` — the backend now splits first render
  /// ([TripService.generateOptionOutfit], 409s if already rendered) from
  /// re-rendering an existing one ([TripService.regenerateOptionOutfit],
  /// 400s if never rendered) into two endpoints, so calling the wrong one
  /// for the option's current state fails outright. Captures the day index
  /// up front and re-checks it still points at the same option before
  /// applying the result, so a slow request landing after the user has
  /// switched days (or edited this same day's garments again) can't
  /// clobber a different day's state.
  Future<void> _generateSelectedDayOutfit() async {
    final dayIndex = _selectedDayIndex;
    final before = _dayOutfits[dayIndex];
    final optionId = before.optionId;
    if (optionId == null) return;
    final isRegenerate = before.outfitId != null;

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
          outfitId: (result['outfit_id'] as num?)?.toInt(),
          resultImageUrl: result['result_image_url'] as String?,
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
  }

  /// Lets the user manually swap which suitcase garments make up the
  /// selected day's outfit, reusing [AddOutfitPage]'s per-category slot
  /// picker. Only reachable once Uwearis has generated a plan (there has to be
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
        int.parse(_trip.id),
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
      // Blank — the name shows as its own block below the app bar instead
      // (see build's ListView), so it isn't in the toolbar at all.
      title: '',
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
              value: _TripMenuAction.editActivities,
              icon: const Icon(
                Icons.flight_takeoff,
                size: 20,
                color: AppColors.icon,
              ),
              label: _l10n.editTripActivities,
            ),
            // Regenerating the whole plan stays available once one exists,
            // but demoted to a secondary action — the bottom CTA is
            // reserved for whichever single next step applies (see
            // [_primaryAction]).
            if (_hasTripPlan)
              AppPopupMenu.item(
                value: _TripMenuAction.regeneratePlan,
                icon: const Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: AppColors.icon,
                ),
                label: _l10n.regenerateTripPlan,
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
      case _TripMenuAction.editActivities:
        _editTripActivities();
      case _TripMenuAction.regeneratePlan:
        if (!_generatingPlan) _generatePlan();
      case _TripMenuAction.delete:
        _confirmDeleteTrip();
    }
  }

  Future<void> _editTripName() async {
    final controller = TextEditingController(text: _trip.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.editTripName,
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyle.bold16,
          decoration: appInputDecoration(hint: _l10n.enterTripName),
        ),
        primaryLabel: _l10n.save,
        onPrimary: () => Navigator.pop(ctx, controller.text.trim()),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (result == null || result.isEmpty || result == _trip.name) return;
    await _updateTrip(_trip.copyWith(name: result));
  }

  Future<void> _editTripLegs() async {
    final legsNotifier = ValueNotifier<List<TripLeg>>(List.of(_trip.legs));
    final result = await showDialog<List<TripLeg>>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.editDestinations,
        content: TripLegsEditor(legsNotifier: legsNotifier),
        primaryLabel: _l10n.save,
        onPrimary: () => Navigator.pop(ctx, legsNotifier.value),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    legsNotifier.dispose();

    if (result == null || result.isEmpty) return;
    await _updateTrip(_trip.copyWith(legs: result));
  }

  Future<void> _editTripActivities() async {
    final selected = _trip.activities
        .map(tripActivityFromApiValue)
        .whereType<TripActivity>()
        .toSet();

    final result = await showDialog<Set<TripActivity>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: _l10n.editTripActivities,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final activity in TripActivity.values)
                CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.accent,
                  value: selected.contains(activity),
                  title: Text(
                    activity.localizedLabel(context),
                    style: AppTextStyle.regular16,
                  ),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selected.add(activity);
                    } else {
                      selected.remove(activity);
                    }
                  }),
                ),
            ],
          ),
          primaryLabel: _l10n.save,
          onPrimary: () => Navigator.pop(ctx, selected),
          secondaryLabel: _l10n.cancel,
          onSecondary: () => Navigator.pop(ctx),
        ),
      ),
    );

    if (result == null) return;
    await _updateTrip(
      _trip.copyWith(activities: result.map((a) => a.apiValue).toList()),
    );
  }

  /// Persists a trip metadata edit (name/legs/activities) and reflects it
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
        activities:
            setEquals(updated.activities.toSet(), previous.activities.toSet())
            ? null
            : updated.activities,
        days: days,
      );
      if (legsChanged && mounted) {
        final refreshed = await TripDetailsPage.preload(updated);
        if (mounted) {
          setState(() {
            _dayOutfits = refreshed.dayOutfits;
            _suitcaseIds = refreshed.suitcaseIds;
            _selectedDayIndex = _dayOutfits.isEmpty
                ? 0
                : _selectedDayIndex.clamp(0, _dayOutfits.length - 1);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _trip = previous);
      ref.read(tripsProvider.notifier).updateTrip(previous);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
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
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to delete trip: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToDeleteTrip)));
    }
  }

  /// The single primary CTA for this page — see [_primaryAction]. Returns
  /// null (no bottom bar at all) once the selected day already has a
  /// current outfit image, so it never competes with the "⋮" menu on the
  /// image itself.
  Widget? _buildBottomBar() {
    switch (_primaryAction) {
      case TripGenerationAction.generateTripPlan:
        return BottomActionButton(
          label: _l10n.generateTripPlan,
          onPressed: _generatingPlan ? null : _generatePlan,
          isLoading: _generatingPlan,
          leading: const Icon(Icons.auto_awesome_outlined),
        );
      case TripGenerationAction.generateOutfit:
        return _buildOutfitActionButton(_l10n.generateOutfit);
      case TripGenerationAction.regenerateOutfit:
        return _buildOutfitActionButton(_l10n.regenerateOutfit);
      case TripGenerationAction.none:
        return null;
    }
  }

  Widget _buildOutfitActionButton(String label) {
    return BottomActionButton(
      label: label,
      onPressed: _generatingOutfit ? null : _generateSelectedDayOutfit,
      isLoading: _generatingOutfit,
      leading: const Icon(Icons.auto_awesome_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only reserve the floating button's full clearance when one is
    // actually showing (_buildBottomBar can return null) — otherwise the
    // last card (garment thumbnails included) has nothing to scroll clear
    // of and ends up covered/cut off by it, same fix outfit_details_page
    // already applies for its own bottom bar.
    final bottomBar = _buildBottomBar();
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          extendBody: true,
          appBar: _buildAppBar(),
          bottomNavigationBar: bottomBar,
          // A single scrollable list (rather than a fixed header Column with
          // only the bottom section scrolling) so dragging from anywhere on
          // screen — including the trip header/insight/suitcase/day-selector
          // area — scrolls the whole page, not just the section below them.
          body: ListView(
            padding: EdgeInsets.only(
              bottom: bottomBar != null
                  ? AppDimens.bottomActionBtnClearance
                  : 32,
            ),
            children: [
              const SizedBox(height: 20),
              _paddedSection(Text(_trip.name, style: AppTextStyle.bold20)),
              _paddedSection(
                const AppDivider(
                  topSpacing: 12,
                  bottomSpacing: AppDimens.sectionSpacing,
                ),
              ),
              _paddedSection(_buildTripHeader()),
              const SizedBox(height: AppDimens.sectionSpacing),
              _paddedSection(_buildUwearisInsightCard()),
              const SizedBox(height: AppDimens.sectionSpacing),
              _paddedSection(_buildSuitcaseSection()),
              const SizedBox(height: AppDimens.sectionSpacing),
              _paddedSection(_buildDayPlanCard()),
            ],
          ),
        ),
        if (_generatingPlan)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingPlanEllipsis),
          ),
        if (_generatingOutfit)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingOutfitEllipsis),
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
            child: SectionTitle(_l10n.dailyOutfitPlan),
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _buildTripDaySelector(),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _paddedSection(_buildOutfitDateHeader()),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _paddedSection(_buildOutfitSection()),
          const SizedBox(height: AppDimens.cardHeaderGap),
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
            if (hasOption)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openDayOutfitEditor,
                child: const Icon(
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

  /// Purely a display of the selected day's outfit — the actual "generate"/
  /// "regenerate" action lives on the single bottom CTA (see
  /// [_buildBottomBar]) so this card never competes with it. Once an image
  /// exists, its own "⋮" menu covers regenerating or changing garments
  /// without needing a visible primary button at all.
  Widget _buildOutfitSection() {
    final outfit = _currentDayOutfit;
    final outfitId = outfit?.outfitId;
    return TodayOutfitIdea(
      imageUrl: outfit?.resultImageUrl,
      hasAssignment: outfit?.optionId != null,
      isLoading: _generatingOutfit,
      jobStatus: _l10n.generatingOutfitEllipsis,
      cacheKey: outfitId == null ? null : 'trip-outfit-$outfitId',
      onRefreshUrl: outfitId == null ? null : _refreshOutfitImageUrl,
      onRegenerate: outfitId == null ? null : _generateSelectedDayOutfit,
      onChangeGarments: outfitId == null ? null : _openDayOutfitEditor,
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

  Widget _buildTripHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _trip.legs.length; i++) ...[
            if (i > 0) _buildLegDivider(),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _trip.legs[i].location.name,
                    style: AppTextStyle.bold16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${DateFormat('MMM d').format(_trip.legs[i].dateRange.start)} - "
                  "${DateFormat('MMM d').format(_trip.legs[i].dateRange.end)}",
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const AppDivider(spacing: 8, color: AppColors.dividerStrong),
    );
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
        height: 102,
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
          EdgeFadeScrim(
            child: SizedBox(
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
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 28),
            const SizedBox(height: 8),
            SectionTitle(_l10n.letUwearisPlanOutfits),
            const SizedBox(height: 4),
            Text(
              _l10n.letUwearisPlanOutfitsHint,
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

  Widget _buildUwearisInsightCard() {
    if (!_loadingPackingAdvice &&
        (_packingAdvice == null || _packingAdvice!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return UwearisInsightCard(
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
          : ExpandableInsightBody(
              title: SectionTitle(
                _l10n.outfitAdviceLabel,
                style: AppTextStyle.regular16,
              ),
              detail: _packingAdvice!,
              detailLineHeight: 1.5,
              expanded: _packingAdviceExpanded,
              onToggle: () => setState(
                () => _packingAdviceExpanded = !_packingAdviceExpanded,
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
}
