import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../app/explore_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/daily_outfit_provider.dart';
import '../../../core/providers/garments_provider.dart';
import '../../../core/providers/outfits_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/trips_provider.dart';
import '../../../core/providers/weather_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/services/base_service.dart';
import '../../../core/services/outfit_service.dart';
import '../../../core/utils/date_locale.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/garment.dart';
import '../../../data/outfit.dart';
import '../../../data/profile_data.dart';
import '../../../data/trip.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/buttons/settings_button.dart';
import '../../widgets/common/buttons/space_switch_button.dart';
import '../../widgets/common/cards/card_corner_badge.dart';
import '../../widgets/common/carousel_dots_indicator.dart';
import '../../widgets/common/home_getting_started_view.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/images/refreshable_network_image.dart';
import '../../widgets/common/labeled_divider.dart';
import '../../widgets/common/overlays/error_dialog.dart';
import '../../widgets/common/overlays/error_state_widget.dart';
import '../../widgets/common/wardrobe_nav_bar.dart';
import '../../widgets/garment/garment_card.dart';
import '../../widgets/garment/garment_upload_helper.dart';
import '../../widgets/outfit/outfit_image.dart';
import '../../widgets/trip/trip_card.dart';
import '../settings/my_outfit_profile_page.dart';
import '../settings/personal_details_page.dart';
import 'create_outfit_page.dart';
import 'garment_details_page.dart';
import 'outfit_details_page.dart';
import 'today_outfit_page.dart';
import 'trips_page.dart';

class WardrobeHomePage extends ConsumerStatefulWidget {
  const WardrobeHomePage({
    super.key,
    @visibleForTesting DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Test seam for simulating a day boundary; [DateTime.now] otherwise.
  final DateTime Function() _now;

  @override
  ConsumerState<WardrobeHomePage> createState() => _WardrobeHomePageState();
}

class _WardrobeHomePageState extends ConsumerState<WardrobeHomePage>
    with WidgetsBindingObserver {
  int _todayOutfitIndex = 0;
  final PageController _todayOutfitPageController = PageController();
  final Set<int> _fallbackFavoriteInFlight = {};

  // Home stays mounted for the app's lifetime (IndexedStack tab), so a day
  // boundary has to be detected here rather than on the next cold start.
  late DateTime _lastSeenDate;
  Timer? _dateCheckTimer;

  bool _openingAddOutfit = false;

  /// Providers that have finished loading since this Home was mounted.
  /// Each sign-in mounts a new Home while the providers
  /// `invalidateSignedInProviders` reset still carry the previous account's
  /// value, so a value is trusted only once its first load here completes;
  /// after that a refresh keeps showing it.
  final Set<ProviderBase<AsyncValue<Object?>>> _settledProviders = {};

  AppLocalizations get _l10n => AppLocalizations.of(context);

  T? _trustedValue<T>(ProviderBase<AsyncValue<T>> provider) {
    final state = ref.watch(provider);
    return _settledProviders.contains(provider) ? state.value : null;
  }

  /// Whether [provider]'s answer is known: a trusted value, or a first
  /// load that has finally failed (not between retries).
  bool _isKnown(ProviderBase<AsyncValue<Object?>> provider) {
    final state = ref.watch(provider);
    return _settledProviders.contains(provider) ||
        (!state.isLoading && !state.retrying);
  }

  /// A first load that has finally failed, so its data is unknown.
  bool _hasFailed(ProviderBase<AsyncValue<Object?>> provider) =>
      _isKnown(provider) &&
      !_settledProviders.contains(provider) &&
      ref.watch(provider).hasError;

  List<Outfit> get _todayOutfits =>
      _trustedValue(dailyOutfitProvider) ?? const [];

  Outfit? get _todayOutfit => _todayOutfitIndex < _todayOutfits.length
      ? _todayOutfits[_todayOutfitIndex]
      : null;

  List<Outfit> get _ownOutfits => _trustedValue(outfitsProvider) ?? const [];

  /// Shown in place of Today's Outfit when today has no plan. `.first` is
  /// the newest because [OutfitsNotifier] fetches `created_at_desc`.
  Outfit? get _latestOwnOutfit =>
      _ownOutfits.isNotEmpty ? _ownOutfits.first : null;

  // Getting Started is derived from real data, never an isFirstLogin-style
  // flag, so a returning user skips it and a mid-setup user lands on the
  // right step.
  ProfileData? get _profileData => _trustedValue(profileProvider);

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
      (_trustedValue(garmentsProvider) ?? const <Garment>[]).active;
  bool get _hasTop =>
      _closetGarments.any((g) => g.category == GarmentCategory.top);
  bool get _hasBottom =>
      _closetGarments.any((g) => g.category == GarmentCategory.bottom);
  bool get _hasShoes =>
      _closetGarments.any((g) => g.category == GarmentCategory.shoes);
  bool get _hasRequiredCloset => _hasTop && _hasBottom && _hasShoes;

  bool get _hasCreatedOutfit => _ownOutfits.isNotEmpty;
  bool get _hasAnyTrip => (_trustedValue(tripsProvider) ?? const []).isNotEmpty;

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

  static final _modeProviders = <ProviderBase<AsyncValue<Object?>>>[
    garmentsProvider,
    profileProvider,
    outfitsProvider,
    tripsProvider,
  ];

  /// Normal Home is shown as soon as the data loaded so far proves the
  /// user is set up, so sections can then fill in one by one. Getting
  /// Started needs every step's data, or it would flash wrong checkmarks —
  /// and a failed load would read as an empty closet.
  _HomeMode get _homeMode {
    final known = _modeProviders.map(_isKnown).toList();
    if (_hasRequiredCloset && (_hasCreatedOutfit || _hasAnyTrip)) {
      return _HomeMode.normal;
    }
    if (known.contains(false)) return _HomeMode.unknown;
    if (_modeProviders.any(_hasFailed)) return _HomeMode.failed;
    return _isGettingStarted ? _HomeMode.gettingStarted : _HomeMode.normal;
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
    _listenToHomeData(dailyOutfitProvider);
    _listenToHomeData(profileProvider);
    _listenToHomeData(garmentsProvider);
    _listenToHomeData(outfitsProvider);
    _listenToHomeData(tripsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(dailyOutfitProvider.notifier).refreshIfNeeded();
    });
  }

  /// Rebuilds come from the `ref.watch`es in build; this only records
  /// first loads and auth expiry. No other wardrobe tab watches
  /// [profileProvider], so its auth expiry is routed here.
  void _listenToHomeData(ProviderBase<AsyncValue<Object?>> provider) {
    ref.listenManual(provider, (_, next) {
      if (!next.isLoading && !next.hasError) _settledProviders.add(provider);
      if (isSettledAuthExpiry(next)) {
        // WardrobeShellScope's lookup isn't safe during initState.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) AuthExpiredHandler.handle(context);
        });
      }
    }, fireImmediately: true);
  }

  /// The shell overlay covers Home until [_homeMode] is known; after that
  /// each section shows its own loading state. Everything it depends on
  /// rebuilds Home, so it's derived here; the shell ignores repeats.
  /// Deferred because [WardrobeShellScope.setLoading] rebuilds the shell.
  void _reportHomeLoading(_HomeMode mode) {
    final label = _openingAddOutfit
        ? _l10n.loadingGarmentsEllipsis
        : mode == _HomeMode.unknown
        ? _l10n.loadingHomeEllipsis
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WardrobeShellScope.of(
        context,
      )?.setLoading(label != null, label: label, tab: WardrobeTab.home);
    });
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
    // Yesterday's plan must not show as today's while the new one loads.
    setState(() {
      _todayOutfitIndex = 0;
      _settledProviders.remove(dailyOutfitProvider);
    });
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

  /// Blank until [_homeMode] is known — the shell overlay covers it (see
  /// [_reportHomeLoading]).
  Widget _buildBody() {
    final mode = _homeMode;
    _reportHomeLoading(mode);
    if (mode == _HomeMode.unknown) return const SizedBox.shrink();
    final bottomClearance =
        AppDimens.navBarClearance + MediaQuery.of(context).padding.bottom;
    if (mode == _HomeMode.failed) {
      final failed = _modeProviders.where(_hasFailed).toList();
      return Padding(
        padding: EdgeInsets.only(bottom: bottomClearance),
        child: ErrorStateWidget(
          error: ref.read(failed.first).error!,
          onRetry: () {
            for (final provider in failed) {
              ref.invalidate(provider);
            }
          },
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ...mode == _HomeMode.gettingStarted
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
            onGetStarted: _openPersonalDetailsForOnboarding,
            onSetUpVirtualModel: _openMyOutfitProfile,
            onAddClothing: _addGarment,
            onCreateOutfit: _openAddOutfit,
          ),
        ],
      ),
    ),
  ];

  /// PersonalDetailsPage continues on to MyOutfitProfilePage in onboarding mode.
  void _openPersonalDetailsForOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PersonalDetailsPage(completingOnboarding: true),
      ),
    );
  }

  void _openMyOutfitProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyOutfitProfilePage()),
    );
  }

  void _addGarment() {
    GarmentUploadHelper.showAddClothingDialog(
      context,
      onAdded: (g) => ref.read(garmentsProvider.notifier).addGarment(g),
    );
  }

  Future<void> _openAddOutfit() async {
    if (_openingAddOutfit) return;
    setState(() => _openingAddOutfit = true);
    Object? failure;
    try {
      await ref.read(garmentsProvider.future);
    } catch (e) {
      failure = e;
    }
    if (!mounted) return;
    // Cleared before any dialog, so the overlay isn't left behind it.
    setState(() => _openingAddOutfit = false);
    switch (failure) {
      case null:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateOutfitPage()),
        );
      case AuthExpiredException():
        await AuthExpiredHandler.handle(context);
      case SessionChangedException():
        // Its session ended meanwhile; whatever ended it owns the UI now.
        break;
      default:
        debugLog('WardrobeHomePage._openAddOutfit: $failure');
        showErrorDialog(context, message: _l10n.failedToLoadGarments);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _l10n.navHome,
      titleWidget: Text(
        'Uwearis',
        textScaler: TextScaler.noScaling,
        style: AppTextStyle.brandTitleToolbar,
      ),
      showBackButton: false,
      leading: AppConfig.enableExplore ? _buildExploreButton() : null,
      leadingWidth: AppConfig.enableExplore ? 148 : null,
      actions: const [SettingsButton()],
    );
  }

  Widget _buildExploreButton() {
    return Padding(
      padding: const EdgeInsets.only(left: ActionDisc.edgeInset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SpaceSwitchButton(
          label: _l10n.explore,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExploreShell()),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final weatherAsync = ref.watch(weatherProvider);
    final dateStr = DateFormat(
      _l10n.homeHeaderDatePattern,
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
    // Until both are known it's undecided whether a daily pick or the
    // latest-outfit fallback fills this slot.
    if (!_isKnown(dailyOutfitProvider) ||
        (_todayOutfits.isEmpty && !_isKnown(outfitsProvider))) {
      return _buildOutfitCardFrame(
        label: null,
        image: Container(
          color: AppColors.surface,
          alignment: Alignment.center,
          child: const AppSpinner(),
        ),
      );
    }
    final dailyOutfit = _todayOutfit;
    // No plan today: show the newest outfit rather than a blank section.
    final fallbackOutfit = dailyOutfit == null ? _latestOwnOutfit : null;
    final outfit = dailyOutfit ?? fallbackOutfit;
    if (outfit == null) return const SizedBox.shrink();
    final isFallbackOutfit = dailyOutfit == null;
    final options = isFallbackOutfit ? [outfit] : _todayOutfits;
    final hasImage = outfit.imageUrl.isNotEmpty;
    return _buildOutfitCardFrame(
      label: isFallbackOutfit ? _l10n.latestOutfitTitle : _l10n.todaysOutfit,
      image: Stack(
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
                          _l10n.noOutfitImageYet,
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
                    final cacheKey = option.displayImageCacheKey;
                    return GestureDetector(
                      onTap: () => isFallbackOutfit
                          ? _openOutfitDetails(option)
                          : _openTodayOutfit(index),
                      child: Container(
                        color: AppColors.surface,
                        child: RefreshableNetworkImage(
                          key: ValueKey(cacheKey),
                          imageUrl: option.imageUrl,
                          cacheKey: cacheKey,
                          fit: BoxFit.cover,
                          errorIconSize: 48,
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
      below: [
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

  /// A null [label] keeps the title's space while it isn't known yet —
  /// the taller of the two titles it can become.
  Widget _buildOutfitCardFrame({
    required String? label,
    required Widget image,
    List<Widget> below = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimens.sectionSpacing),
        if (label != null)
          LabeledDivider(label: label)
        else
          Stack(
            children: [
              for (final title in [_l10n.todaysOutfit, _l10n.latestOutfitTitle])
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: LabeledDivider(label: title),
                ),
            ],
          ),
        const SizedBox(height: AppDimens.cardHeaderGap),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          child: AspectRatio(aspectRatio: 1 / 1.15, child: image),
        ),
        ...below,
      ],
    );
  }

  /// The [_latestOwnOutfit] fallback lives in [outfitsProvider], not
  /// [dailyOutfitProvider], so it's toggled there.
  Future<void> _toggleFavorite(
    Outfit target, {
    required bool isFallback,
  }) async {
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
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now. The
      // heart was already rolled back where it was toggled.
    } catch (e) {
      if (!mounted) return;
      debugLog('WardrobeHomePage._toggleFavorite: $e');
      showErrorDialog(context, message: _l10n.failedToUpdateFavorite);
    }
  }

  /// Same one-request-per-outfit rule as
  /// [DailyOutfitNotifier.toggleOutfitFavorite].
  Future<void> _toggleFallbackFavorite(Outfit target) async {
    if (!_fallbackFavoriteInFlight.add(target.id)) return;
    final outfits = ref.read(outfitsProvider.notifier);
    final next = target.copyWith(isFavorite: !target.isFavorite);
    final token = outfits.updateOutfitFavoriteOptimistically(
      target.id,
      isFavorite: next.isFavorite,
    );
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        isFavorite: next.isFavorite,
      );
      outfits.settleOutfitFavorite(
        target.id,
        token,
        isFavorite: next.isFavorite,
      );
    } catch (_) {
      outfits.settleOutfitFavorite(
        target.id,
        token,
        isFavorite: target.isFavorite,
      );
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
    final trips = _trustedValue(tripsProvider) ?? const <Trip>[];
    final today = _dateOnly(widget._now());
    final upcoming =
        trips.where((t) => _dateOnly(t.dateRange.start).isAfter(today)).toList()
          ..sort((a, b) => a.dateRange.start.compareTo(b.dateRange.start));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimens.sectionSpacing),
        LabeledDivider(label: _l10n.upcomingTrip),
        const SizedBox(height: AppDimens.cardHeaderGap),
        _buildTripCard(upcoming.first),
      ],
    );
  }

  Widget _buildTripCard(Trip trip) {
    return TripCard(
      key: ValueKey(trip.id),
      trip: trip,
      onTap: () => openTripDetails(context, ref, trip, tab: WardrobeTab.home),
      onNameChanged: (name) => handleRenameTrip(context, ref, trip, name),
      onDelete: () => handleDeleteTrip(context, ref, trip),
    );
  }

  /// Garments have no created-at timestamp; ids are assumed
  /// auto-incrementing, so id-descending approximates newest-first.
  Widget _buildRecentlyAddedSection() {
    final garments = _closetGarments;
    if (garments.isEmpty) return const SizedBox.shrink();

    final recent = [...garments]
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    final shown = recent.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimens.sectionSpacing),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LabeledDivider(label: _l10n.recentlyAdded),
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

  Future<void> _openGarment(Garment garment) =>
      GarmentDetailsPage.open(context, ref, garment);
}

enum _HomeMode { unknown, failed, gettingStarted, normal }
