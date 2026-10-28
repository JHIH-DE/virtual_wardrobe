import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/daily_outfit_provider.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trips_provider.dart';
import '../../core/providers/weather_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/profile_data.dart';
import '../../data/trip.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/buttons/action_disc_button.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/carousel_dots_indicator.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/main_nav_bar.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_upload_helper.dart';
import '../widgets/home/home_getting_started_view.dart';
import '../widgets/outfit/outfit_image.dart';
import '../widgets/trip/trip_card.dart';
import 'account_page.dart';
import 'create_outfit_page.dart';
import 'explore_page.dart';
import 'garment_details_page.dart';
import 'outfit_details_page.dart';
import 'settings_page.dart';
import 'today_outfit_page.dart';
import 'trips_page.dart';
import '../../core/utils/date_locale.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, @visibleForTesting DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Test seam for simulating a day boundary; [DateTime.now] otherwise.
  final DateTime Function() _now;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  int _todayOutfitIndex = 0;
  final PageController _todayOutfitPageController = PageController();
  final Set<int> _fallbackFavoriteInFlight = {};

  // Home stays mounted for the app's lifetime (IndexedStack tab), so a day
  // boundary has to be detected here rather than on the next cold start.
  late DateTime _lastSeenDate;
  Timer? _dateCheckTimer;

  List<Outfit> get _todayOutfits =>
      ref.watch(dailyOutfitProvider).value ?? const [];

  Outfit? get _todayOutfit => _todayOutfitIndex < _todayOutfits.length
      ? _todayOutfits[_todayOutfitIndex]
      : null;

  /// Shown in place of Today's Outfit when today has no plan. `.first` is
  /// the newest because [OutfitsNotifier] fetches `created_at_desc`.
  Outfit? get _latestOwnOutfit {
    final outfits = ref.watch(outfitsProvider).value ?? const [];
    return outfits.isNotEmpty ? outfits.first : null;
  }

  // Getting Started is derived from real data, never an isFirstLogin-style
  // flag, so a returning user skips it and a mid-setup user lands on the
  // right step.
  ProfileData? get _profileData => ref.watch(profileProvider).value;

  /// Account's four required fields (name/gender/birthday/home location).
  bool get _hasAboutYou {
    final profile = _profileData?.profile;
    if (profile == null) return false;
    return profile.name.trim().isNotEmpty &&
        (profile.gender?.isNotEmpty ?? false) &&
        profile.birthDate != null &&
        (profile.location?.isNotEmpty ?? false);
  }

  bool get _hasProfilePhoto => _profileData?.hasFaceReference ?? false;
  bool get _hasFullBodyPhoto => _profileData?.hasBodyReference ?? false;
  List<Garment> get _closetGarments =>
      (ref.watch(garmentsProvider).value ?? const []).active;
  bool get _hasTop =>
      _closetGarments.any((g) => g.category == GarmentCategory.top);
  bool get _hasBottom =>
      _closetGarments.any((g) => g.category == GarmentCategory.bottom);
  bool get _hasShoes =>
      _closetGarments.any((g) => g.category == GarmentCategory.shoes);
  bool get _hasRequiredCloset => _hasTop && _hasBottom && _hasShoes;

  bool get _hasCreatedOutfit =>
      (ref.watch(outfitsProvider).value ?? const []).isNotEmpty;
  bool get _hasAnyTrip =>
      (ref.watch(tripsProvider).value ?? const []).isNotEmpty;

  /// An established user who later deletes a reference photo (to retake
  /// it) shouldn't be sent back through the photo steps.
  bool get _isEstablishedUser =>
      _hasRequiredCloset || _hasCreatedOutfit || _hasAnyTrip;

  /// [_hasAnyTrip] stands in for [_hasCreatedOutfit] for established users:
  /// [outfitsProvider] excludes trip outfits, so a trip-only user would
  /// otherwise be stuck here forever.
  bool get _isGettingStarted {
    if (_isEstablishedUser) {
      return !_hasRequiredCloset || (!_hasCreatedOutfit && !_hasAnyTrip);
    }
    return !_hasAboutYou ||
        !_hasProfilePhoto ||
        !_hasFullBodyPhoto ||
        !_hasRequiredCloset ||
        !_hasCreatedOutfit;
  }

  /// Deliberately `!isLoading` without `hasValue`: after sign-in,
  /// `invalidateSignedInProviders` leaves the previous account's value
  /// attached while loading, which would flash that account's state.
  bool get _gettingStartedDataReady {
    final profile = ref.watch(profileProvider);
    final garments = ref.watch(garmentsProvider);
    final outfits = ref.watch(outfitsProvider);
    final trips = ref.watch(tripsProvider);
    return !profile.isLoading &&
        !garments.isLoading &&
        !outfits.isLoading &&
        !trips.isLoading;
  }

  @override
  void initState() {
    super.initState();
    _lastSeenDate = _dateOnly(widget._now());
    WidgetsBinding.instance.addObserver(this);
    _dateCheckTimer = Timer.periodic(_dateCheckInterval, (_) {
      _refreshIfDateChanged();
      ref.read(weatherProvider.notifier).refreshIfStale();
    });
    // MainShellScope's lookup isn't safe during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reportHomeLoading();
      ref.listenManual(dailyOutfitProvider, (_, _) => _reportHomeLoading());
      ref.listenManual(profileProvider, (_, _) => _reportHomeLoading());
      ref.listenManual(garmentsProvider, (_, _) => _reportHomeLoading());
      ref.listenManual(outfitsProvider, (_, _) => _reportHomeLoading());
      ref.listenManual(tripsProvider, (_, _) => _reportHomeLoading());
      ref.read(dailyOutfitProvider.notifier).refreshIfNeeded();
    });
  }

  /// One shell-level loading state over every provider the body reads.
  /// No other main tab watches [profileProvider], so its auth expiry is
  /// routed to [AuthExpiredHandler] here.
  void _reportHomeLoading() {
    final states = [
      ref.read(dailyOutfitProvider),
      ref.read(profileProvider),
      ref.read(garmentsProvider),
      ref.read(outfitsProvider),
      ref.read(tripsProvider),
    ];
    for (final state in states) {
      if (state.hasError && state.error is AuthExpiredException) {
        AuthExpiredHandler.handle(context);
        break;
      }
    }
    // Plain isLoading — see [_gettingStartedDataReady].
    final loading = states.any((s) => s.isLoading);
    MainShellScope.of(context)?.setLoading(
      loading,
      label: AppLocalizations.of(context).loading,
      tab: MainTab.home,
    );
  }

  /// Catches midnight while the app stays foregrounded (no lifecycle
  /// event fires). A poll, not a one-shot Timer to midnight: Timer runs on
  /// monotonic time and goes stale if the wall clock/timezone changes.
  static const _dateCheckInterval = Duration(minutes: 1);

  /// A backgrounded isolate can be suspended, so the poll may not fire;
  /// resume is what catches a day change in that case.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _refreshIfDateChanged();
    ref.read(weatherProvider.notifier).refreshIfStale();
  }

  void _refreshIfDateChanged() {
    if (!mounted) return;
    final today = _dateOnly(widget._now());
    if (today == _lastSeenDate) return;
    _lastSeenDate = today;
    setState(() => _todayOutfitIndex = 0);
    if (_todayOutfitPageController.hasClients) {
      _todayOutfitPageController.jumpToPage(0);
    }
    ref.read(dailyOutfitProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateCheckTimer?.cancel();
    _todayOutfitPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// Blank while loading — the shell overlay covers it (see
  /// [_reportHomeLoading]).
  Widget _buildBody() {
    if (!_gettingStartedDataReady) return const SizedBox.shrink();
    final bottomClearance =
        AppDimens.mainNavBarClearance + MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ..._isGettingStarted
              ? _buildGettingStartedContent()
              : _buildNormalHomeContent(),
          SizedBox(height: bottomClearance),
        ],
      ),
    );
  }

  List<Widget> _buildNormalHomeContent() => [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildOutfitImageCard(),
          _buildUpcomingTripSection(),
        ],
      ),
    ),
    _buildRecentlyAddedSection(),
  ];

  List<Widget> _buildGettingStartedContent() => [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeGettingStartedView(
            hasAboutYou: _hasAboutYou,
            hasProfilePhoto: _hasProfilePhoto,
            hasFullBodyPhoto: _hasFullBodyPhoto,
            hasTop: _hasTop,
            hasBottom: _hasBottom,
            hasShoes: _hasShoes,
            hasCreatedOutfit: _hasCreatedOutfit,
            onGetStarted: _openAccountPageForOnboarding,
            onAddClothing: _addGarment,
            onCreateOutfit: _openAddOutfit,
          ),
        ],
      ),
    ),
  ];

  /// AccountPage continues on to MyOutfitProfilePage in onboarding mode.
  void _openAccountPageForOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountPage(completingOnboarding: true),
      ),
    );
  }

  void _addGarment() {
    GarmentUploadHelper.showAddClothingDialog(
      context,
      onAdded: (g) => ref.read(garmentsProvider.notifier).addGarment(g),
    );
  }

  Future<void> _openAddOutfit() async {
    final l10n = AppLocalizations.of(context);
    MainShellScope.of(
      context,
    )?.setLoading(true, label: l10n.loadingGarments, tab: MainTab.home);
    try {
      await ref.read(garmentsProvider.future);
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: MainTab.home);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateOutfitPage()),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: MainTab.home);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      MainShellScope.of(context)?.setLoading(false, tab: MainTab.home);
      debugLog('HomePage._openAddOutfit: $e');
      showErrorDialog(context, message: l10n.failedToLoadGarments);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: AppLocalizations.of(context).navHome,
      titleWidget: Text(
        'Uwearis',
        textScaler: TextScaler.noScaling,
        style: AppTextStyle.brandTitleToolbar,
      ),
      showBackButton: false,
      leading: _buildExploreButton(),
      leadingWidth: 136,
      actions: [
        ActionDiscButton(
          icon: Image.asset(
            'assets/images/setting.png',
            height: ActionDisc.iconSize,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExploreButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AccentPillButton(
          label: AppLocalizations.of(context).explore,
          variant: AccentPillButtonVariant.toolbar,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExplorePage()),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final weatherAsync = ref.watch(weatherProvider);
    final dateStr = DateFormat(
      AppLocalizations.of(context).homeHeaderDatePattern,
      dateLocaleOf(context),
    ).format(widget._now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...weatherAsync.maybeWhen(
          data: (w) => [_buildWeatherBadge(w), const SizedBox(width: 14)],
          orElse: () => const <Widget>[],
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dateStr, style: AppTextStyle.bold20.copyWith(fontSize: 19)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  weatherAsync.when(
                    data: (w) => _headerChip(
                      icon: Icons.thermostat_rounded,
                      label: '${w.low}°C - ${w.high}°C',
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  weatherAsync.maybeWhen(
                    data: (w) => _headerChip(
                      icon: Icons.location_on_outlined,
                      label: w.location,
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

  /// The current conditions, large, beside the date and temperature.
  Widget _buildWeatherBadge(WeatherData weather) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: weather.isDay
            ? AppColors.weatherBadgeDay
            : AppColors.weatherBadgeNight,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(weather.iconAsset, width: 46, height: 46),
    );
  }

  Widget _headerChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.headerChipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.headerChipIcon),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyle.bold14.copyWith(
              color: AppColors.headerChipText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitImageCard() {
    final l10n = AppLocalizations.of(context);
    final dailyOutfit = _todayOutfit;
    // No plan today: show the newest outfit rather than a blank section.
    final fallbackOutfit = dailyOutfit == null ? _latestOwnOutfit : null;
    final outfit = dailyOutfit ?? fallbackOutfit;
    if (outfit == null) return const SizedBox.shrink();
    final isFallbackOutfit = dailyOutfit == null;
    final options = isFallbackOutfit ? [outfit] : _todayOutfits;
    final hasImage = outfit.imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimens.sectionSpacing),
        LabeledDivider(
          label: isFallbackOutfit ? l10n.latestOutfitTitle : l10n.todaysOutfit,
        ),
        const SizedBox(height: AppDimens.cardHeaderGap),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          child: AspectRatio(
            aspectRatio: 1 / 1.15,
            child: Stack(
              fit: StackFit.expand,
              children: [
                !hasImage
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
                        itemCount: options.length,
                        itemBuilder: (_, index) {
                          final option = options[index];
                          return GestureDetector(
                            onTap: () => isFallbackOutfit
                                ? _openOutfitDetails(option)
                                : _openTodayOutfit(index),
                            child: Container(
                              color: AppColors.surface,
                              child: RefreshableNetworkImage(
                                key: ValueKey(
                                  outfitImageVersionedCacheKey(option.id),
                                ),
                                imageUrl: option.imageUrl,
                                cacheKey: outfitImageVersionedCacheKey(
                                  option.id,
                                ),
                                fit: BoxFit.cover,
                                errorIconSize: 48,
                                placeholderBuilder: (_) =>
                                    Container(color: AppColors.surface),
                                fadeInDuration: const Duration(
                                  milliseconds: 200,
                                ),
                                onRefreshUrl: () => fetchFreshOutfitImageUrl(
                                  option.groupId,
                                  option.id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                if (hasImage)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: CardCornerBadge(
                      icon: outfit.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      backgroundColor: AppColors.surfaceTranslucent,
                      iconColor: outfit.isFavorite
                          ? AppColors.favorite
                          : AppColors.hintText,
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: const [],
                      size: 36,
                      iconSize: 20,
                      discAlignment: Alignment.bottomRight,
                      onTap: () =>
                          _toggleFavorite(outfit, isFallback: isFallbackOutfit),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasImage && options.length > 1) ...[
          const SizedBox(height: 10),
          CarouselDotsIndicator(
            count: options.length,
            currentIndex: _todayOutfitIndex,
          ),
        ],
      ],
    );
  }

  /// The [_latestOwnOutfit] fallback lives in [outfitsProvider], not
  /// [dailyOutfitProvider], so it's toggled there.
  Future<void> _toggleFavorite(
    Outfit target, {
    required bool isFallback,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (isFallback) {
        await _toggleFallbackFavorite(target);
      } else {
        await ref
            .read(dailyOutfitProvider.notifier)
            .toggleOutfitFavorite(target);
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('HomePage._toggleFavorite: $e');
      showErrorDialog(context, message: l10n.failedToUpdateFavorite);
    }
  }

  /// Same one-request-per-outfit rule as
  /// [DailyOutfitNotifier.toggleOutfitFavorite].
  Future<void> _toggleFallbackFavorite(Outfit target) async {
    if (!_fallbackFavoriteInFlight.add(target.id)) return;
    final outfits = ref.read(outfitsProvider.notifier);
    final next = target.copyWith(isFavorite: !target.isFavorite);
    outfits.updateOutfit(next);
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        isFavorite: next.isFavorite,
      );
    } catch (_) {
      outfits.updateOutfit(target);
      rethrow;
    } finally {
      _fallbackFavoriteInFlight.remove(target.id);
    }
  }

  void _openOutfitDetails(Outfit outfit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OutfitDetailsPage(outfit: outfit)),
    );
  }

  /// Swiping in TodayOutfitPage moves this carousel too, so coming back
  /// lands on the option last viewed.
  void _openTodayOutfit(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodayOutfitPage(
          initialIndex: index,
          onIndexChanged: (i) {
            if (!mounted) return;
            setState(() => _todayOutfitIndex = i);
            if (_todayOutfitPageController.hasClients) {
              _todayOutfitPageController.jumpToPage(i);
            }
          },
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Widget _buildUpcomingTripSection() {
    final trips = ref.watch(tripsProvider).value ?? const <Trip>[];
    final today = _dateOnly(widget._now());
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

  Widget _buildTripCard(Trip trip) {
    return TripCard(
      key: ValueKey(trip.id),
      trip: trip,
      onTap: () => openTripDetails(context, ref, trip, tab: MainTab.home),
      onNameChanged: (name) => handleRenameTrip(context, ref, trip, name),
      onDelete: () => handleDeleteTrip(context, ref, trip),
    );
  }

  /// Garments have no created-at timestamp; ids are assumed
  /// auto-incrementing, so id-descending approximates newest-first.
  Widget _buildRecentlyAddedSection() {
    final garments = (ref.watch(garmentsProvider).value ?? const []).active;
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
    // Edits auto-save and sync garmentsProvider from inside the page; only
    // a delete comes back as a result.
    if (result == 'deleted' && garment.id != null) {
      ref.read(garmentsProvider.notifier).removeGarment(garment.id!);
    }
  }
}
