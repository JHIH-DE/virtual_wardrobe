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
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/trip.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/outfit/outfit_image.dart';
import '../widgets/trip/trip_card.dart';
import 'garment_details_page.dart';
import 'outfit_details_page.dart';
import 'settings_page.dart';
import 'trip_details_page.dart';
import 'trips_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _loadingOutfit = true;
  // Every outfit option Uwearis generated for today — generation/rendering all
  // happens server-side on its own schedule now, so this is a plain read;
  // empty means no plan exists yet for today.
  List<Outfit> _todayOutfits = const [];
  // Which of [_todayOutfits] is shown as the main preview — swiping the
  // carousel below updates this.
  int _todayOutfitIndex = 0;
  final PageController _todayOutfitPageController = PageController();

  Outfit? get _todayOutfit => _todayOutfitIndex < _todayOutfits.length
      ? _todayOutfits[_todayOutfitIndex]
      : null;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame — MainShellScope.of below needs an
    // ancestor lookup that isn't safe to run during initState itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDailyOutfit();
    });
  }

  @override
  void dispose() {
    _todayOutfitPageController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyOutfit() async {
    setState(() => _loadingOutfit = true);
    MainShellScope.of(context)?.setLoading(
      true,
      label: AppLocalizations.of(context).loading,
      tab: AppTab.home,
    );
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final outfits = await DailyOutfitService().getDailyOutfit(today);
      if (!mounted) return;
      setState(() {
        _todayOutfits = outfits ?? const [];
        _todayOutfitIndex = 0;
      });
      if (_todayOutfitPageController.hasClients) {
        _todayOutfitPageController.jumpToPage(0);
      }
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to load daily outfit: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingOutfit = false);
        MainShellScope.of(context)?.setLoading(false, tab: AppTab.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // floatingNavBarClearance alone is tuned for the nav bar's own height,
    // not any given device's safe-area inset — add that explicitly so the
    // last card always clears the floating nav bar, gesture-bar devices
    // included, without touching the nav bar's own layout.
    final bottomClearance =
        AppDimens.floatingNavBarClearance +
        MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
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
                  const SizedBox(height: AppDimens.sectionSpacing),
                  _buildOutfitImageCard(),
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

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: AppLocalizations.of(context).navHome,
      titleWidget: Text(
        'Uwearis',
        textScaler: TextScaler.noScaling,
        style: AppTextStyle.brandTitle,
      ),
      showBackButton: false,
      leading: _buildExploreButton(),
      leadingWidth: 128,
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

  // Visual only for now — no destination page/feature wired up yet.
  Widget _buildExploreButton() {
    return Padding(
      // Matches the default back-arrow's effective left inset (IconButton's
      // own 8px Material padding + its 2px inner glyph padding).
      padding: const EdgeInsets.only(left: 8),
      // AppBar's leading slot hands its child a *tight* height constraint
      // (locked to the full toolbar height) — Center converts that to a
      // loose constraint so the pill's own `height` below actually applies
      // instead of being stretched to fill the toolbar.
      child: Center(
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.accent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_outlined,
                size: 15,
                color: AppColors.accent,
              ),
              const SizedBox(width: 5),
              Text(
                'Explore',
                style: AppTextStyle.bold14.copyWith(color: AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
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
    final outfit = _todayOutfit;
    final hasImage =
        !_loadingOutfit && outfit != null && outfit.imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDivider(label: l10n.todaysOutfit),
        const SizedBox(height: AppDimens.cardHeaderGap),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          child: AspectRatio(
            aspectRatio: 1 / 1.15,
            child: _loadingOutfit
                // Shell-level overlay (see _loadDailyOutfit) covers the
                // whole screen while loading, so this stays blank.
                ? Container(color: AppColors.surface)
                : !hasImage
                ? Container(
                    color: AppColors.surface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.checkroom,
                            size: 48,
                            color: AppColors.icon,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noOutfitImageYet,
                            style: AppTextStyle.regular13.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: _todayOutfitPageController,
                    onPageChanged: (index) =>
                        setState(() => _todayOutfitIndex = index),
                    itemCount: _todayOutfits.length,
                    itemBuilder: (_, index) {
                      final option = _todayOutfits[index];
                      return GestureDetector(
                        onTap: () => _openOutfitDetails(option),
                        child: Container(
                          color: AppColors.surface,
                          child: RefreshableNetworkImage(
                            imageUrl: option.imageUrl,
                            cacheKey: outfitImageCacheKey(option.id),
                            fit: BoxFit.cover,
                            errorIconSize: 48,
                            // Plain white background instead of a loading
                            // spinner, with a quick cross-fade once the
                            // image actually loads — matches
                            // GarmentImage/OutfitImage's quieter treatment.
                            placeholderBuilder: (_) =>
                                Container(color: AppColors.surface),
                            fadeInDuration: const Duration(milliseconds: 200),
                            onRefreshUrl: () => fetchFreshOutfitImageUrl(
                              option.groupId,
                              option.id,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        if (hasImage && _todayOutfits.length > 1) ...[
          const SizedBox(height: 10),
          _buildOutfitPageIndicator(),
        ],
        if (hasImage &&
            outfit.reasoning != null &&
            outfit.reasoning!.isNotEmpty) ...[
          const SizedBox(height: AppDimens.sectionSpacing),
          UwearisInsightCard(child: _buildReasoningLines(outfit.reasoning!)),
        ],
      ],
    );
  }

  /// Outfit.reasoning joins multiple points into one string with `\n` —
  /// render each as its own bulleted line rather than one dense paragraph.
  Widget _buildReasoningLines(String reasoning) {
    final lines = reasoning.split('\n').where((l) => l.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: AppTextStyle.regular14),
                Expanded(
                  child: Text(line.trim(), style: AppTextStyle.regular14),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Dots marking which of today's outfit options is shown, plus a
  /// "current / total" counter trailing them — mirrors Outfit Details' own
  /// version carousel indicator.
  Widget _buildOutfitPageIndicator() {
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_todayOutfits.length, (index) {
                final isActive = index == _todayOutfitIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accent : AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_todayOutfitIndex + 1} / ${_todayOutfits.length}',
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOutfitDetails(Outfit outfit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitDetailsPage(
          outfit: outfit,
          isNew: false,
          // This outfit's group is `type: "daily"`, not "general" — a
          // version created here would land back in that same daily group,
          // which outfits_page.dart's list never fetches (it only reads
          // `type: "general"` groups), so it'd be unreachable afterwards.
          // showAddToMyOutfits offers a real way to keep it instead: a
          // fresh render of the same garments/background into a new
          // general group.
          showEditOutfitWhenSaved: false,
          showAddToMyOutfits: true,
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Same "upcoming" grouping trips_page.dart uses for its own section —
  /// just the single soonest trip, since Home only has room for a preview.
  Widget _buildUpcomingTripSection() {
    final trips = ref.watch(tripsProvider).value ?? const <Trip>[];
    final today = _dateOnly(DateTime.now());
    final upcoming =
        trips.where((t) => _dateOnly(t.dateRange.start).isAfter(today)).toList()
          ..sort((a, b) => a.dateRange.start.compareTo(b.dateRange.start));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimens.sectionSpacing),
        LabeledDivider(label: l10n.upcomingTrip),
        const SizedBox(height: AppDimens.cardHeaderGap),
        _buildTripCard(upcoming.first),
      ],
    );
  }

  // Just the single soonest trip is ever shown here (see
  // _buildUpcomingTripSection), so unlike a real list of cards this doesn't
  // need its own trailing cardSpacing — the gap before the next section's
  // divider comes from that section's own leading spacer instead, the same
  // way every other divider on this page gets its "before" gap.
  Widget _buildTripCard(Trip trip) {
    return TripCard(
      key: ValueKey(trip.id),
      trip: trip,
      onTap: () => _openTrip(trip),
      onNameChanged: (name) => handleRenameTrip(context, ref, trip, name),
      onDelete: () => handleDeleteTrip(context, ref, trip),
    );
  }

  Future<void> _openTrip(Trip trip) async {
    final l10n = AppLocalizations.of(context);
    MainShellScope.of(
      context,
    )?.setLoading(true, label: l10n.loadingTripEllipsis, tab: AppTab.home);
    try {
      final data = await TripDetailsPage.preload(trip);
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: AppTab.home);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDetailsPage(trip: trip, initialData: data),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: AppTab.home);
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
    final garments = ref.watch(garmentsProvider).value ?? const [];
    if (garments.isEmpty) return const SizedBox.shrink();

    final recent = [...garments]
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    final shown = recent.take(8).toList();

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimens.sectionSpacing),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LabeledDivider(label: l10n.recentlyAdded),
        ),
        const SizedBox(height: AppDimens.cardHeaderGap),
        SizedBox(
          height: AppDimens.garmentCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: shown.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppDimens.sectionSpacing),
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
