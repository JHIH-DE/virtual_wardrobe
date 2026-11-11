import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/garments_provider.dart';
import '../core/providers/outfits_provider.dart';
import '../core/providers/points_provider.dart';
import '../core/providers/trip_detail_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/shared_media_handler.dart';
import '../core/utils/daily_points_notice.dart';
import '../core/utils/debug_log.dart';
import '../core/utils/pending_try_on_recovery.dart';
import '../data/points.dart';
import '../features/pages/wardrobe/closet_page.dart';
import '../features/pages/wardrobe/create_outfit_page.dart';
import '../features/pages/wardrobe/outfits_page.dart';
import '../features/pages/wardrobe/trips_page.dart';
import '../features/pages/wardrobe/wardrobe_home_page.dart';
import '../features/widgets/common/overlays/app_snack_bar.dart';
import '../features/widgets/common/overlays/error_dialog.dart';
import '../features/widgets/common/overlays/loading_overlay.dart';
import '../features/widgets/common/wardrobe_nav_bar.dart';
import '../features/widgets/garment/garment_upload_helper.dart';
import '../l10n/generated/app_localizations.dart';

/// Keeps the 4 wardrobe tabs alive in an [IndexedStack] (scroll position and
/// filters survive tab switches) and owns the nav bar and its quick actions.
class WardrobeShell extends ConsumerStatefulWidget {
  const WardrobeShell({super.key});

  @override
  ConsumerState<WardrobeShell> createState() => _WardrobeShellState();
}

class _WardrobeShellState extends ConsumerState<WardrobeShell>
    with WidgetsBindingObserver {
  WardrobeTab _current = WardrobeTab.home;
  // Keyed by tab so a hidden tab's background fetch never shows the overlay
  // over the visible tab.
  final Map<WardrobeTab, String?> _loadingLabelByTab = {};

  bool _recoveringTryOns = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Post-frame: inherited-widget lookups aren't safe during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SharedMediaHandler.listen(context, ref);
      _recoverPendingTryOns();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recoverPendingTryOns();
      // Another device may have spent points, or a new day's grant landed.
      unawaited(ref.read(pointsProvider.notifier).reloadPoints());
    }
  }

  Future<void> _showDailyPointsNotice(PointsSummary summary) async {
    if (!await DailyPointsNotice.takeIfDue(summary) || !mounted) return;
    showAppSnackBar(
      context,
      AppLocalizations.of(context).pointsDailyGranted(summary.dailyGrant),
    );
  }

  /// Try-ons whose outcome the app lost (killed or backgrounded mid-render):
  /// Create Outfit, regenerate, and trip outfit try-ons.
  Future<void> _recoverPendingTryOns() async {
    if (_recoveringTryOns) return;
    _recoveringTryOns = true;
    // Read before the await: the shell may be gone by then.
    final outfits = ref.read(outfitsProvider.notifier);
    try {
      final found = await recoverPendingTryOns();
      if (found.outfitsLanded > 0) unawaited(outfits.refresh());
      for (final MapEntry(key: tripId, value: collection)
          in found.trips.entries) {
        // A trip nobody has open fetches fresh when it's next opened.
        final trip = tripDetailProvider(tripId);
        if (mounted && ref.exists(trip)) {
          ref.read(trip.notifier).setCollection(collection);
        }
      }
    } catch (e) {
      debugLog('WardrobeShell: try-on recovery failed: $e');
    } finally {
      _recoveringTryOns = false;
    }
  }

  void _select(WardrobeTab tab) {
    if (tab != _current) setState(() => _current = tab);
  }

  void _setGlobalLoading(
    bool loading, {
    String? label,
    required WardrobeTab tab,
  }) {
    final next = loading ? (label ?? '') : null;
    if (_loadingLabelByTab[tab] == next) return;
    setState(() {
      if (next == null) {
        _loadingLabelByTab.remove(tab);
      } else {
        _loadingLabelByTab[tab] = next;
      }
    });
  }

  /// Swipe left/right anywhere to cycle tabs (wrapping). An in-page
  /// horizontal scroller wins the gesture arena for drags that start on it.
  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 200.0;
    final tabs = WardrobeTab.values;
    final i = tabs.indexOf(_current);
    if (velocity < -threshold) {
      _select(tabs[(i + 1) % tabs.length]);
    } else if (velocity > threshold) {
      _select(tabs[(i - 1 + tabs.length) % tabs.length]);
    }
  }

  Future<void> _handleQuickAction(QuickAction action) async {
    switch (action) {
      case QuickAction.addClothing:
        GarmentUploadHelper.showAddClothingDialog(
          context,
          onAdded: (g) {
            ref.read(garmentsProvider.notifier).addGarment(g);
            _select(WardrobeTab.closet);
          },
        );
      case QuickAction.addOutfit:
        await openAddOutfit(context, ref);
      case QuickAction.newTrip:
        await handleCreateTrip(
          context,
          ref,
          onCreated: () => _select(WardrobeTab.tripPlanner),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pointsProvider, (_, next) {
      final summary = next.value;
      if (summary != null && next is AsyncData) {
        unawaited(_showDailyPointsNotice(summary));
      }
    });
    return WardrobeShellScope(
      selectTab: _select,
      setLoading: _setGlobalLoading,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleSwipe,
            child: IndexedStack(
              index: WardrobeTab.values.indexOf(_current),
              children: const [
                WardrobeHomePage(),
                ClosetPage(),
                OutfitsPage(),
                TripsPage(),
              ],
            ),
          ),
          WardrobeNavBar(
            current: _current,
            onSelect: _select,
            onQuickAction: _handleQuickAction,
            credits: ref.watch(pointsProvider).value?.balance,
          ),
          // Painted last so it also covers WardrobeNavBar.
          if (_loadingLabelByTab[_current] != null)
            LoadingOverlay(label: _loadingLabelByTab[_current]!),
        ],
      ),
    );
  }
}

/// Warms [garmentsProvider] behind a modal [LoadingOverlay], then pushes
/// [CreateOutfitPage]. Also used by `SharedMediaHandler` for a shared-in photo.
Future<void> openAddOutfit(
  BuildContext context,
  WidgetRef ref, {
  String? initialMatchALookImagePath,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    builder: (_) => LoadingOverlay(
      label: AppLocalizations.of(context).loadingGarmentsEllipsis,
    ),
  );
  try {
    // Also lets an expired session surface here.
    await ref.read(garmentsProvider.future);
    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOutfitPage(
          onBack: () => Navigator.popUntil(context, (route) => route.isFirst),
          initialMatchALookImagePath: initialMatchALookImagePath,
        ),
      ),
    );
  } on AuthExpiredException {
    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    await AuthExpiredHandler.handle(context);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // close loading indicator
    debugLog('Failed to load garments: $e');
    showErrorDialog(
      context,
      message: AppLocalizations.of(context).failedToLoadGarments,
    );
  }
}
