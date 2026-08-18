import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/trips_provider.dart';
import '../../core/providers/weather_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/daily_outfit_service.dart';
import '../../core/services/outfit_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/try_on_mixin.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/trip.dart';
import '../../l10n/generated/app_localizations.dart';
import 'garment_details_page.dart';
import 'outfit_details_page.dart';
import 'settings_page.dart';
import 'trip_details_page.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/cards/lumi_insight_card.dart';
import '../widgets/common/buttons/pill_button.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/outfit/outfit_image.dart';
import '../widgets/trip/trip_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TryOnMixin {
  bool _loadingOutfit = true;
  String? _reasoning;
  List<int> _garmentIds = [];

  @override
  void initState() {
    super.initState();
    _loadDailyOutfit();
  }

  Future<void> _loadDailyOutfit() async {
    setState(() => _loadingOutfit = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      var outfit = await DailyOutfitService().getDailyOutfit(today);
      if (outfit == null) {
        await DailyOutfitService().generateDailyOutfit(date: today);
        outfit = await DailyOutfitService().getDailyOutfit(today);
      }
      if (outfit == null) return;

      final options =
          ((outfit['options'] as List?) ?? [])
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort(
              (a, b) => ((a['order_index'] as num?) ?? 0).compareTo(
                (b['order_index'] as num?) ?? 0,
              ),
            );

      if (options.isEmpty) {
        if (mounted) setState(() => _reasoning = null);
        return;
      }

      final option = options.first;
      final items = ((option['items'] as List?) ?? [])
          .whereType<Map<String, dynamic>>();
      final garmentIds = items
          .map((i) => (i['garment_id'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      if (mounted) {
        final rawReasoning = option['reasoning'];
        setState(() {
          _garmentIds = garmentIds;
          if (rawReasoning is List) {
            _reasoning = rawReasoning.map((e) => '• $e').join('\n');
          } else {
            _reasoning = rawReasoning as String?;
          }
        });
      }

      final lookId = option['look_id'] as int?;
      debugLog('--- _loadDailyOutfit - look_id: $lookId ---');
      if (lookId != null && lookId != 0) {
        await _watchLook(lookId);
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load daily outfit: $e');
    } finally {
      if (mounted) setState(() => _loadingOutfit = false);
    }
  }

  /// Polls a single look directly by its own id (`OutfitService.getLook`)
  /// until it completes. The daily outfit option hands back a `look_id`,
  /// not an `outfit_id` — [TryOnMixin.watchJob] expects the latter, so it
  /// doesn't apply here even though it sets the same [tryOnResultUrl] /
  /// [isOutfitLoading] state this page's UI already reads.
  Future<void> _watchLook(int lookId) async {
    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
    });
    for (var attempt = 0; attempt < 180; attempt++) {
      if (!mounted) return;
      try {
        final look = await OutfitService().getLook(lookId);
        final status = look['status'];
        debugLog('--- _watchLook lookId=$lookId status=$status ---');
        if (status == 'completed') {
          if (!mounted) return;
          setState(() {
            isOutfitLoading = false;
            tryOnResultUrl = look['result_image_url'] as String?;
            tryOnOutfitId = (look['outfit_id'] as num?)?.toInt() ?? 0;
          });
          return;
        }
        if (status == 'failed') {
          if (!mounted) return;
          setState(() {
            isOutfitLoading = false;
            tryOnErrorMessage =
                (look['error_message'] as String?) ?? 'Failed on server.';
          });
          return;
        }
      } on AuthExpiredException {
        rethrow;
      } catch (e) {
        debugLog('_watchLook polling error: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    if (mounted) {
      setState(() {
        isOutfitLoading = false;
        tryOnErrorMessage = 'Timeout.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  AppToolBar _buildAppBar(BuildContext context) {
    return AppToolBar(
      title: AppLocalizations.of(context).navHome,
      titleWidget: Text(
        'Aseri',
        textScaler: TextScaler.noScaling,
        style: AppTextStyle.brandTitle,
      ),
      showBackButton: false,
      actions: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          borderRadius: BorderRadius.circular(22),
          // Fixed 44x44 touch target — the glyph itself stays at
          // iconMediumSize, only the tappable area grows to meet the
          // minimum comfortable touch target.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Image.asset(
                'assets/images/setting.png',
                height: AppDimens.iconMediumSize,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    // floatingNavBarClearance alone is tuned for the nav bar's own height,
    // not any given device's safe-area inset — add that explicitly so the
    // last card always clears the floating nav bar, gesture-bar devices
    // included, without touching the nav bar's own layout.
    final bottomClearance =
        AppDimens.floatingNavBarClearance +
        MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildOutfitImageCard(),
                  const SizedBox(height: 12),
                  _buildLumiInsightCard(),
                  _buildUpcomingTripSection(),
                ],
              ),
            ),
            // Outside the 24px page padding so the horizontal card scroller
            // itself isn't boxed in and can reach the true screen edges —
            // the section's own label keeps the 24px inset internally so it
            // still lines up with the rest of the page.
            _buildRecentlyAddedSection(),
            SizedBox(height: bottomClearance),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final weatherAsync = ref.watch(weatherProvider);
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ~14% smaller than title22, keeping title22's weight family
              // (bold, not title22's black/w900) so it stays clearly above
              // the metadata pills without reading as heavy as the logo.
              Text(dateStr, style: AppTextStyle.bold20.copyWith(fontSize: 19)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  weatherAsync.when(
                    data: (w) => _headerChip(
                      icon: Icon(
                        WeatherData.iconFromCondition(w.condition),
                        size: 16,
                        color: AppColors.statusUpcoming,
                      ),
                      label: '${w.low}°C - ${w.high}°C',
                      tint: AppColors.statusUpcoming,
                    ),
                    loading: () => _headerChip(
                      icon: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: l10n.loadingWeatherEllipsis,
                      tint: AppColors.statusUpcoming,
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  weatherAsync.maybeWhen(
                    data: (w) => _headerChip(
                      icon: const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.statusOngoing,
                      ),
                      label: w.location,
                      tint: AppColors.statusOngoing,
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerChip({
    required Widget icon,
    required String label,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        // Softer/paler than before — a metadata pill shouldn't compete with
        // the outfit photo for attention.
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyle.bold14.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitImageCard() {
    final l10n = AppLocalizations.of(context);
    final loading = _loadingOutfit || isOutfitLoading;
    final imageUrl = tryOnResultUrl;
    final hasResult = !loading && imageUrl != null && imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDivider(label: l10n.todaysOutfit),
        const SizedBox(height: 14),
        GestureDetector(
          // The whole photo is the tap target now — the pill in the corner
          // is just a visual hint, not a separate control (see IgnorePointer
          // below), so this is the only thing that actually navigates.
          onTap: hasResult ? _openOutfitDetails : null,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1 / 1.15,
                  child: Container(
                    color: AppColors.surface,
                    child: loading
                        ? LoadingOverlay(label: l10n.generatingOutfitEllipsis)
                        : (imageUrl == null || imageUrl.isEmpty)
                        ? Center(
                            child: Icon(
                              Icons.checkroom,
                              size: 48,
                              color: AppColors.icon,
                            ),
                          )
                        : RefreshableNetworkImage(
                            imageUrl: imageUrl,
                            // Re-signed URL each fetch shouldn't defeat the
                            // disk cache — same scheme as OutfitImage/
                            // trip_details_page.dart's outfit image.
                            cacheKey: tryOnOutfitId != 0
                                ? 'outfit-job-$tryOnOutfitId'
                                : null,
                            fit: BoxFit.cover,
                            errorIconSize: 48,
                            onRefreshUrl: _refreshTryOnResultUrl,
                          ),
                  ),
                ),
              ),
              if (hasResult)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IgnorePointer(
                    child: PillButton(
                      label: Text(l10n.viewDetails, style: AppTextStyle.bold12),
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 9,
                        color: AppColors.icon,
                      ),
                      onTap: _openOutfitDetails,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      mainAxisAlignment: MainAxisAlignment.start,
                      gap: 4,
                      border: null,
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.overlaySubtle,
                          blurRadius: 4,
                        ),
                      ],
                      color: AppColors.surfaceTranslucent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _refreshTryOnResultUrl() async {
    if (tryOnOutfitId == 0) return null;
    try {
      final freshUrl = await fetchFreshOutfitImageUrl(tryOnOutfitId);
      if (mounted && freshUrl.isNotEmpty) {
        setState(() => tryOnResultUrl = freshUrl);
      }
      return freshUrl;
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return null;
    }
  }

  void _openOutfitDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitDetailsPage(
          outfit: Outfit(
            id: tryOnOutfitId,
            imageUrl: tryOnResultUrl!,
            advice: tryOnAiAdvice,
            garmentIds: _garmentIds,
          ),
          isNew: true,
          confirmLeaveOnBack: false,
        ),
      ),
    );
  }

  Widget _buildLumiInsightCard() {
    if (_reasoning == null || _reasoning!.isEmpty) {
      return const SizedBox.shrink();
    }
    return LumiInsightCard(
      child: Text(
        _reasoning!,
        style: AppTextStyle.regular14.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Same "upcoming" grouping trips_page.dart uses for its own section —
  /// just the single soonest trip, since Home only has room for a preview.
  Widget _buildUpcomingTripSection() {
    final trips = ref.watch(tripsProvider).valueOrNull ?? const <Trip>[];
    final today = _dateOnly(DateTime.now());
    final upcoming =
        trips.where((t) => _dateOnly(t.dateRange.start).isAfter(today)).toList()
          ..sort((a, b) => a.dateRange.start.compareTo(b.dateRange.start));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        LabeledDivider(label: l10n.upcomingTrip),
        const SizedBox(height: 16),
        _buildTripCard(upcoming.first),
      ],
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TripCard(
        key: ValueKey(trip.id),
        trip: trip,
        onTap: () => _openTrip(trip),
        onNameChanged: (name) =>
            _updateTrip(trip, updated: trip.copyWith(name: name)),
        onLegsChanged: (legs) =>
            _updateTrip(trip, updated: trip.copyWith(legs: legs)),
        onActivitiesChanged: (activities) =>
            _updateTrip(trip, updated: trip.copyWith(activities: activities)),
        onDelete: () => _deleteTrip(trip),
      ),
    );
  }

  Future<void> _updateTrip(Trip trip, {required Trip updated}) async {
    try {
      await TripService().updateTrip(
        int.parse(trip.id),
        name: updated.name != trip.name ? updated.name : null,
        legs: updated.legs,
        activities: setEquals(
              updated.activities.toSet(),
              trip.activities.toSet(),
            )
            ? null
            : updated.activities,
      );
      if (!mounted) return;
      ref.read(tripsProvider.notifier).updateTrip(updated);
    } catch (e) {
      if (!mounted) return;
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to update trip: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToUpdateTrip),
        ),
      );
    }
  }

  Future<void> _deleteTrip(Trip trip) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await TripService().deleteTrip(int.parse(trip.id));
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      ref.read(tripsProvider.notifier).remove(trip.id);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to delete trip: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToDeleteTrip),
        ),
      );
    }
  }

  Future<void> _openTrip(Trip trip) async {
    final l10n = AppLocalizations.of(context);
    MainShellScope.of(
      context,
    )?.setLoading(true, label: l10n.loadingTripEllipsis);
    try {
      final data = await TripDetailsPage.preload(trip);
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDetailsPage(trip: trip, initialData: data),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load trip details: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToLoadTripDetails)));
      }
    }
  }

  /// The backend doesn't return a created-at timestamp for garments yet —
  /// id is assumed auto-incrementing, so sorting by it descending is the
  /// best available "most recently added first" ordering.
  Widget _buildRecentlyAddedSection() {
    final garments = ref.watch(garmentsProvider).valueOrNull ?? const [];
    if (garments.isEmpty) return const SizedBox.shrink();

    final recent = [...garments]
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    final shown = recent.take(8).toList();

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LabeledDivider(label: l10n.recentlyAdded),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: AppDimens.garmentCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: AppDimens.garmentCardWidth,
              child: GarmentCard(
                garment: shown[i],
                showSelectionIndicator: false,
                onTap: () => _openGarment(shown[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openGarment(Garment garment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentDetailsPage(initialGarment: garment),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted' && garment.id != null) {
      ref.read(garmentsProvider.notifier).removeGarment(garment.id!);
    } else if (result is Garment) {
      ref.read(garmentsProvider.notifier).updateGarment(result);
    }
  }
}
