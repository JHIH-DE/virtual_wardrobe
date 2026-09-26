import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../core/services/daily_outfit_service.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/profile_data.dart';
import '../../data/trip.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/carousel_dots_indicator.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/cards/uwearis_insight_card.dart';
import '../widgets/common/main_nav_bar.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_upload_helper.dart';
import '../widgets/home/home_getting_started_view.dart';
import '../widgets/outfit/outfit_image.dart';
import '../widgets/trip/trip_card.dart';
import 'account_page.dart';
import 'add_outfit_page.dart';
import 'explore_page.dart';
import 'garment_details_page.dart';
import 'outfit_details_page.dart';
import 'settings_page.dart';
import 'trips_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, @visibleForTesting DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Testing seam only — lets a test simulate a day boundary being crossed
  /// (see [_HomePageState.didChangeAppLifecycleState]) without waiting on
  /// the real system clock. Always [DateTime.now] outside tests.
  final DateTime Function() _now;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  // Which of the daily outfit options is shown as the main preview —
  // swiping the carousel below updates this.
  int _todayOutfitIndex = 0;
  final PageController _todayOutfitPageController = PageController();

  // Synchronous re-entrancy guard for _getFirstDailyOutfit — set as its
  // first statement, before any await, per CLAUDE.md's "Guarding costly /
  // mutating actions against double-invocation" (two sequential AI calls,
  // up to ~90s each — the shell's LoadingOverlay alone doesn't close the
  // one-frame double-tap gap that guard is about).
  bool _generatingFirstDailyOutfit = false;

  // Home stays mounted for the app's whole lifetime (it's one of MainShell's
  // IndexedStack tabs, so initState only ever runs once) — this is what lets
  // didChangeAppLifecycleState/_dateCheckTimer below notice a day boundary
  // crossed while the app was backgrounded, or just left open, instead of
  // only picking it up on the next cold start.
  late DateTime _lastSeenDate;
  Timer? _dateCheckTimer;

  List<Outfit> get _todayOutfits =>
      ref.watch(dailyOutfitProvider).value ?? const [];

  Outfit? get _todayOutfit => _todayOutfitIndex < _todayOutfits.length
      ? _todayOutfits[_todayOutfitIndex]
      : null;

  /// The newest entry in "My Outfits" — shown in place of Today's Outfit
  /// when the server hasn't generated a daily plan yet (see
  /// [_buildOutfitImageCard]). [OutfitsNotifier] fetches with
  /// `sort: 'created_at_desc'`, so `.first` is already the most recently
  /// created one; no id-based sort needed (unlike
  /// [_buildRecentlyAddedSection]'s garments, which have no such ordering
  /// guarantee from their own provider).
  Outfit? get _latestOwnOutfit {
    final outfits = ref.watch(outfitsProvider).value ?? const [];
    return outfits.isNotEmpty ? outfits.first : null;
  }

  // Getting Started state — derived from real data (profileProvider's
  // account fields + reference photos, garmentsProvider's closet,
  // outfitsProvider's "My Outfits"), never a single isFirstLogin-style
  // flag, so a returning user who already finished setup never sees it
  // again and a mid-setup user always lands on the right step. A complete
  // initial flow is About You + Profile Photo + Full-Body Photo + a closet
  // covering Top/Bottom/Shoes + the first created outfit — Home stays on
  // Getting Started until all five are true. All three providers are also
  // watched by other always-mounted IndexedStack tabs (Account/My Virtual
  // Model/Settings watch profileProvider; ClosetPage watches
  // garmentsProvider; OutfitsPage/OutfitDetailsPage watch/refresh
  // outfitsProvider) and are updated in place by their own upload/add/save
  // flows, so this reflects the latest state on return from any of them
  // without any extra refresh/didPopNext plumbing.
  ProfileData? get _profileData => ref.watch(profileProvider).value;

  /// Account's four required fields (name/gender/birthday/home location)
  /// all filled in — see `AccountPage`'s own `_hasRequiredAboutYouFields`,
  /// which this mirrors.
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

  // Fixed thresholds for _buildDailyOutfitsUnlockCard — a flat product rule
  // ("enough per-category variety to actually generate daily outfits"), not
  // anything the backend returns (getDailyOutfit only says whether today's
  // plan exists, never why one might be missing), so there's nothing to
  // fetch here.
  static const _dailyOutfitTopTarget = 6;
  static const _dailyOutfitBottomTarget = 4;
  static const _dailyOutfitShoesTarget = 3;

  int _categoryCount(GarmentCategory category) =>
      _closetGarments.where((g) => g.category == category).length;

  bool get _dailyOutfitsUnlocked =>
      _categoryCount(GarmentCategory.top) >= _dailyOutfitTopTarget &&
      _categoryCount(GarmentCategory.bottom) >= _dailyOutfitBottomTarget &&
      _categoryCount(GarmentCategory.shoes) >= _dailyOutfitShoesTarget;

  bool get _hasCreatedOutfit =>
      (ref.watch(outfitsProvider).value ?? const []).isNotEmpty;
  bool get _hasAnyTrip =>
      (ref.watch(tripsProvider).value ?? const []).isNotEmpty;

  /// True once there's real evidence this is an established user — a
  /// completed closet, a created outfit, or a planned trip — any one of
  /// which could only exist after they'd already been through (or past)
  /// the photo step once. Deleting a reference photo later (to retake it,
  /// say) shouldn't send an established user all the way back through the
  /// welcome/profile-photo screen; only [_hasRequiredCloset]/
  /// [_hasCreatedOutfit] still gate them once this is true (see
  /// [_isGettingStarted] for [_hasAnyTrip]'s extra role there).
  bool get _isEstablishedUser =>
      _hasRequiredCloset || _hasCreatedOutfit || _hasAnyTrip;

  /// [_hasAnyTrip] stands in for [_hasCreatedOutfit] in the established-user
  /// branch below — [outfitsProvider] only ever holds standalone "My
  /// Outfits" looks (daily/trip outfits are filtered out server-side, see
  /// `outfits_provider.dart`), so a user who plans trips and only ever gets
  /// daily/trip-generated outfits (never a standalone one) would otherwise
  /// never satisfy [_hasCreatedOutfit] and would stay stuck on this screen
  /// forever, hiding a Today's Outfit the backend already generated. A
  /// closet-complete user with no trip and no created outfit yet still
  /// needs [_hasCreatedOutfit] itself — planning a trip is real evidence of
  /// outfit-flow use, an empty/default trip list is not.
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

  /// True once every provider [_isGettingStarted] depends on is no longer
  /// loading — plain `!isLoading`, deliberately **not** also checking
  /// `hasValue`. `ref.invalidate` (`invalidateSignedInProviders`, called
  /// right after a successful sign-in — see `auth_handler.dart`) puts a
  /// provider into `AsyncLoading` that still carries the *previous*
  /// account's already-resolved value via Riverpod's own
  /// `copyWithPrevious` — so `hasValue` is already true again on the very
  /// first rebuild after login, well before the fresh fetch for the new
  /// account actually returns. A `isLoading && !hasValue` check (this
  /// getter's first version) reads that stale-but-present value as "ready"
  /// immediately, which is exactly what let a freshly signed-in account
  /// flash the *previous* account's Getting-Started/Home state for the
  /// ~1-2s the real fetch takes before correcting itself. Gating on
  /// `isLoading` alone waits out that whole window regardless of whether a
  /// stale value is attached. A manual `.refresh()` (pull-to-refresh, a
  /// photo/garment upload) still resolves this the same way it always has
  /// — those assign a bare `const AsyncLoading()` with no previous value at
  /// all, so `isLoading` alone already covered them.
  ///
  /// Also guards against briefly rendering the wrong body while the very
  /// first fetch after login is still in flight — mirrors how
  /// [_buildOutfitImageCard] used to gate on `dailyOutfitProvider`'s own
  /// loading flag before this.
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
    _dateCheckTimer = Timer.periodic(
      _dateCheckInterval,
      (_) => _refreshIfDateChanged(),
    );
    // Deferred to after the first frame — MainShellScope's lookup isn't
    // safe to run during initState itself.
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

  /// Combines [dailyOutfitProvider] (Today's Outfit), [profileProvider],
  /// [garmentsProvider], [outfitsProvider] and [tripsProvider] (the latter
  /// four all now also feeding [_isGettingStarted]/[_isEstablishedUser])
  /// into one shell-level loading state for this tab — widens the
  /// single-provider `mainTabReporter` shape (`main_tab_async.dart`) other
  /// main tabs use to cover every source this page's body now reads before
  /// it can decide what to show. `profileProvider` isn't otherwise
  /// triggered/watched by any always-mounted tab, so this is also what
  /// kicks off its first fetch and routes an unrecoverable auth expiry on
  /// it to [AuthExpiredHandler] (garmentsProvider's/outfitsProvider's/
  /// tripsProvider's own expiry is already handled independently by
  /// ClosetPage's/OutfitsPage's/TripsPage's identical listeners).
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
    // Plain isLoading, not `isLoading && !hasValue` — see
    // _gettingStartedDataReady's doc for why the latter misses an
    // in-flight ref.invalidate refetch (its stale previous value already
    // satisfies hasValue), which is exactly the window this overlay needs
    // to keep covering.
    final loading = states.any((s) => s.isLoading);
    MainShellScope.of(context)?.setLoading(
      loading,
      label: AppLocalizations.of(context).loading,
      tab: MainTab.home,
    );
  }

  /// Resuming from background alone isn't enough — an app left open and
  /// foregrounded straight through midnight (screen never off, never
  /// backgrounded) emits no [AppLifecycleState] transition at all, so
  /// nothing would ever notice the day changed. [_dateCheckTimer] is the
  /// other half.
  ///
  /// Deliberately a plain poll, not a one-shot Timer scheduled for the
  /// precise wall-clock delay until the next midnight: Dart's Timer counts
  /// down against elapsed real (monotonic) time, not the wall clock — a
  /// one-shot Timer's delay is computed once and then goes stale the
  /// moment the device's date/time is changed by hand (or a timezone/NTP
  /// change), so it fires at the wrong moment or not at all. Re-reading
  /// [widget._now] fresh every tick sidesteps that: whatever the wall
  /// clock now says, the next tick (at most [_dateCheckInterval] away)
  /// picks it up regardless of how it got there.
  static const _dateCheckInterval = Duration(minutes: 1);

  /// The header's date string and the daily outfit are both computed off
  /// "today" — resuming from background, or [_dateCheckTimer]'s periodic
  /// poll, are the two moments that boundary can have moved without any
  /// rebuild otherwise happening, so recheck it here rather than only on
  /// the next cold start. A backgrounded app's Dart isolate can be
  /// suspended, so the poll isn't guaranteed to keep firing on schedule —
  /// the resume check below is what actually catches that case; the
  /// poll's own job is the "app stayed foregrounded" case the resume check
  /// can't see.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _refreshIfDateChanged();
  }

  void _refreshIfDateChanged() {
    if (!mounted) return;
    final today = _dateOnly(widget._now());
    if (today == _lastSeenDate) return;
    _lastSeenDate = today;
    // New day, new outfit list — yesterday's carousel position doesn't
    // carry over.
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

  /// Blank while the data [_isGettingStarted] depends on is still on its
  /// first fetch (the shell overlay covers the screen for that window — see
  /// [_reportHomeLoading]); otherwise the header (date/weather) is always
  /// shown, and only the content below it swaps between
  /// [_buildGettingStartedContent] and [_buildNormalHomeContent] — decided
  /// fresh on every rebuild so returning from My Virtual Model/Add Clothing/
  /// Add Outfit (still mounted underneath, per IndexedStack) always
  /// reflects the latest state.
  Widget _buildBody() {
    if (!_gettingStartedDataReady) return const SizedBox.shrink();
    // mainNavBarClearance alone is tuned for the nav bar's own height,
    // not any given device's safe-area inset — add that explicitly so the
    // last card always clears the main nav bar, gesture-bar devices
    // included, without touching the nav bar's own layout.
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

  /// Header + Today's Outfit + Upcoming Trip, then Recently Added.
  /// Recently Added is its own list entry rather than nested inside the
  /// padded Column above it, because its horizontal card scroller needs to
  /// reach the true screen edges — it applies the same 24px inset
  /// internally instead (see [_buildRecentlyAddedSection]); nesting it here
  /// would double that padding and choke off its scroll range.
  List<Widget> _buildNormalHomeContent() => [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildOutfitImageCard(),
          _buildDailyOutfitsUnlockCard(),
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
          _buildHeader(),
          const SizedBox(height: AppDimens.sectionSpacing),
          HomeGettingStartedView(
            hasAboutYou: _hasAboutYou,
            hasProfilePhoto: _hasProfilePhoto,
            hasFullBodyPhoto: _hasFullBodyPhoto,
            hasTop: _hasTop,
            hasBottom: _hasBottom,
            hasShoes: _hasShoes,
            onGetStarted: _openAccountPageForOnboarding,
            onAddClothing: _addGarment,
            onCreateOutfit: _openAddOutfit,
          ),
        ],
      ),
    ),
  ];

  /// The profile step's first sub-step — `AccountPage` itself continues on
  /// to `MyVirtualModelPage` once its own required fields are filled in (see
  /// `AccountPage.completingOnboarding`).
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

  /// Triggered by [HomeGettingStartedView]'s "Create Outfit" CTA on its
  /// final "Ready for your first look?" step — mirrors `outfits_page.dart`'s
  /// own `_openAddOutfit` (warm garmentsProvider, then push [AddOutfitPage],
  /// loading routed through [MainShellScope] since this page is itself a
  /// main tab — see CLAUDE.md's main-tab loading convention).
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
        MaterialPageRoute(builder: (_) => const AddOutfitPage()),
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

  /// Triggered by [_buildDailyOutfitsUnlockCard]'s "Get My First Outfit"
  /// CTA, shown once [_dailyOutfitsUnlocked] but no daily outfit exists for
  /// today yet. Two sequential AI calls — [DailyOutfitService.generate]
  /// (text-only: picks today's garments, no image) then
  /// [DailyOutfitService.generateOptionOutfit] on the resulting primary
  /// option (the actual try-on render) — followed by a plain
  /// [dailyOutfitProvider] refresh so [_todayOutfit] picks up the result
  /// the normal way; no extra local state is threaded through, since
  /// _buildOutfitImageCard already reacts to that provider on its own.
  Future<void> _getFirstDailyOutfit() async {
    if (_generatingFirstDailyOutfit) return;
    setState(() => _generatingFirstDailyOutfit = true);
    final l10n = AppLocalizations.of(context);
    MainShellScope.of(context)?.setLoading(
      true,
      label: l10n.generatingOutfitEllipsis,
      tab: MainTab.home,
    );
    try {
      final plan = await DailyOutfitService().generate(date: widget._now());
      final primary = plan.primaryOption;
      if (primary == null) {
        throw Exception('generate returned no primary option');
      }
      await DailyOutfitService().generateOptionOutfit(primary.id);
      if (!mounted) return;
      await ref.read(dailyOutfitProvider.notifier).refresh();
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('HomePage._getFirstDailyOutfit: $e');
      showErrorDialog(context, message: l10n.failedToGenerateOutfit);
    } finally {
      if (mounted) {
        MainShellScope.of(context)?.setLoading(false, tab: MainTab.home);
        setState(() => _generatingFirstDailyOutfit = false);
      }
    }
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
          borderRadius: BorderRadius.circular(AppDimens.toolbarHeight / 2),
          // Fills the toolbar slot (same touch target as the back button /
          // "⋮" menu); the glyph itself stays at the toolbar action-icon
          // size, only the tappable area grows.
          child: SizedBox.square(
            dimension: AppDimens.toolbarHeight,
            child: Center(
              child: Image.asset(
                'assets/images/setting.png',
                height: AppDimens.toolbarActionIconSize,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildExploreButton() {
    return Padding(
      // Matches the default back-arrow's effective left inset (IconButton's
      // own 8px Material padding + its 2px inner glyph padding).
      padding: const EdgeInsets.only(left: 16),
      // centerLeft anchors flush to the 16px inset — matches Explore's
      // "Home" pill.
      child: Align(
        alignment: Alignment.centerLeft,
        child: AccentPillButton(
          label: AppLocalizations.of(context).explore,
          icon: Icons.explore_outlined,
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
    final dateStr = DateFormat('EEEE, MMM d').format(widget._now());

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
    final dailyOutfit = _todayOutfit;
    // _buildNormalHomeBody only renders once _isGettingStarted is false —
    // i.e. the user has already created at least one outfit (see
    // _hasCreatedOutfit) — so no daily outfit *today* just means the server
    // hasn't generated today's plan yet, not "first outfit" any more.
    // Rather than leaving the section blank, fall back to the most
    // recently created "My Outfit" (outfitsProvider fetches newest-first,
    // so `.first` is the newest — see OutfitsNotifier.build/refresh) so
    // there's still something to look at; [_isFallbackOutfit] is what tells the
    // rest of this method (and _openOutfitDetails) that [outfit] came from
    // that fallback rather than the real daily plan.
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
                            onTap: () => _openOutfitDetails(
                              option,
                              isFallback: isFallbackOutfit,
                            ),
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
                    // Same treatment as OutfitDetailsPage's own favourite
                    // badge (see FavoriteCard) — outfit is already exactly
                    // "the currently displayed option" in both the daily
                    // and fallback cases (see _todayOutfit/options above),
                    // so no separate index lookup is needed here.
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
        if (hasImage &&
            outfit.reasoning != null &&
            outfit.reasoning!.isNotEmpty) ...[
          const SizedBox(height: AppDimens.sectionSpacing),
          UwearisInsightCard(child: _buildReasoningLines(outfit.reasoning!)),
        ],
      ],
    );
  }

  /// Below [_dailyOutfitsUnlocked]'s target, nudges an established user
  /// toward the per-category variety it needs — shown regardless of
  /// whether today happens to have a real/fallback outfit above it.
  ///
  /// Once unlocked, switches to a one-time "go get it" prompt instead of
  /// just disappearing: [_todayOutfit] is what actually gates that —
  /// still null means nothing has generated today's real plan yet (neither
  /// this card's own "Get My First Outfit" button nor the backend's daily
  /// cron), so there's something concrete to prompt for. Once it's
  /// non-null, _buildOutfitImageCard's own "Today's Outfit" slot already
  /// shows it, so this card hides for good — same "nothing left to say"
  /// shape as the locked state's own threshold check.
  Widget _buildDailyOutfitsUnlockCard() {
    final l10n = AppLocalizations.of(context);
    if (!_dailyOutfitsUnlocked) {
      return _dailyOutfitsCard(
        title: l10n.dailyOutfitsUnlockTitle,
        body: l10n.dailyOutfitsUnlockBody,
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _unlockCategoryColumn(
              emoji: '👕',
              label: GarmentCategory.top.pluralLabel(context),
              current: _categoryCount(GarmentCategory.top),
              target: _dailyOutfitTopTarget,
            ),
            _unlockCategoryColumn(
              emoji: '👖',
              label: GarmentCategory.bottom.pluralLabel(context),
              current: _categoryCount(GarmentCategory.bottom),
              target: _dailyOutfitBottomTarget,
            ),
            _unlockCategoryColumn(
              emoji: '👟',
              label: GarmentCategory.shoes.pluralLabel(context),
              current: _categoryCount(GarmentCategory.shoes),
              target: _dailyOutfitShoesTarget,
            ),
          ],
        ),
      );
    }

    if (_todayOutfit != null) return const SizedBox.shrink();
    return _dailyOutfitsCard(
      title: l10n.dailyOutfitsUnlockedTitle,
      body: l10n.dailyOutfitsUnlockedBody,
      trailing: Center(
        child: AccentPillButton(
          label: l10n.getFirstDailyOutfitButton,
          icon: Icons.auto_awesome,
          enabled: !_generatingFirstDailyOutfit,
          onPressed: _getFirstDailyOutfit,
        ),
      ),
    );
  }

  Widget _dailyOutfitsCard({
    required String title,
    required String body,
    required Widget trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimens.sectionSpacing),
        AppCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title),
              const SizedBox(height: 8),
              Text(
                body,
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppDimens.sectionSpacing),
              trailing,
            ],
          ),
        ),
      ],
    );
  }

  Widget _unlockCategoryColumn({
    required String emoji,
    required String label,
    required int current,
    required int target,
  }) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyle.medium13.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text('$current / $target', style: AppTextStyle.bold14),
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
                Text('•  ', style: AppTextStyle.insightCardBody),
                Expanded(
                  child: Text(line.trim(), style: AppTextStyle.insightCardBody),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Same optimistic-update-then-revert-on-failure shape as
  /// OutfitDetailsPage's own `_toggleFavorite` — the difference here is
  /// which provider owns [target]: a fallback outfit lives in
  /// [outfitsProvider] ("My Outfits"), a real daily outfit lives in
  /// [dailyOutfitProvider] instead, so the local update (and its revert)
  /// has to go through whichever one actually holds it.
  Future<void> _toggleFavorite(
    Outfit target, {
    required bool isFallback,
  }) async {
    final l10n = AppLocalizations.of(context);
    final next = target.copyWith(isFavorite: !target.isFavorite);
    void applyLocally(Outfit value) {
      if (isFallback) {
        ref.read(outfitsProvider.notifier).updateOutfit(value);
      } else {
        ref.read(dailyOutfitProvider.notifier).updateOutfit(value);
      }
    }

    applyLocally(next);
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        isFavorite: next.isFavorite,
      );
    } on AuthExpiredException {
      if (!mounted) return;
      applyLocally(target);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      applyLocally(target);
      debugLog('HomePage._toggleFavorite: $e');
      showErrorDialog(context, message: l10n.failedToUpdateFavorite);
    }
  }

  /// [isFallback] outfits come from [_latestOwnOutfit] — already a "My
  /// Outfits" (`type: general`) entry, so this opens exactly like
  /// outfits_page.dart's own tap handler (plain defaults: `isNew: false`,
  /// `showEditOutfitWhenSaved: true`, `showAddToMyOutfits: false`) — it's
  /// already reachable from that list, nothing to offer adding it to.
  /// A real daily outfit's group is `type: "daily"`, which
  /// outfits_page.dart's list never fetches (only `type: "general"`), so
  /// it needs the opposite: `showAddToMyOutfits: true` gives it a real way
  /// to become reachable there — a fresh render of the same garments/
  /// background into a new general group.
  void _openOutfitDetails(Outfit outfit, {required bool isFallback}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isFallback
            ? OutfitDetailsPage(outfit: outfit)
            : OutfitDetailsPage(
                outfit: outfit,
                isNew: false,
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

  // Just the single soonest trip is ever shown here (see
  // _buildUpcomingTripSection), so unlike a real list of cards this doesn't
  // need its own trailing cardSpacing — the gap before the next section's
  // divider comes from that section's own leading spacer instead, the same
  // way every other divider on this page gets its "before" gap.
  Widget _buildTripCard(Trip trip) {
    return TripCard(
      key: ValueKey(trip.id),
      trip: trip,
      onTap: () => openTripDetails(context, ref, trip, tab: MainTab.home),
      onNameChanged: (name) => handleRenameTrip(context, ref, trip, name),
      onDelete: () => handleDeleteTrip(context, ref, trip),
    );
  }

  /// The backend doesn't return a created-at timestamp for garments yet —
  /// id is assumed auto-incrementing, so sorting by it descending is the
  /// best available "most recently added first" ordering.
  Widget _buildRecentlyAddedSection() {
    // .active: a soft-deleted garment shouldn't show as "recently added".
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
    if (result == 'deleted' && garment.id != null) {
      ref.read(garmentsProvider.notifier).removeGarment(garment.id!);
    } else if (result is Garment) {
      ref.read(garmentsProvider.notifier).updateGarment(result);
    }
  }
}
