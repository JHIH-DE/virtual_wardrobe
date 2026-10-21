import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/shared_media_handler.dart';
import '../core/utils/debug_log.dart';
import '../features/pages/create_outfit_page.dart';
import '../features/pages/closet_page.dart';
import '../features/pages/home_page.dart';
import '../features/pages/outfits_page.dart';
import '../features/pages/trips_page.dart';
import '../features/widgets/common/main_nav_bar.dart';
import '../features/widgets/common/overlays/error_dialog.dart';
import '../features/widgets/common/overlays/loading_overlay.dart';
import '../features/widgets/garment/garment_upload_helper.dart';
import '../l10n/generated/app_localizations.dart';

/// Keeps the 4 main tabs alive in an [IndexedStack] (scroll position and
/// filters survive tab switches) and owns the nav bar and its quick actions.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  MainTab _current = MainTab.home;
  // Keyed by tab so a hidden tab's background fetch never shows the overlay
  // over the visible tab.
  final Map<MainTab, String?> _loadingLabelByTab = {};

  @override
  void initState() {
    super.initState();
    // Post-frame: inherited-widget lookups aren't safe during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SharedMediaHandler.listen(context, ref);
    });
  }

  void _select(MainTab tab) {
    if (tab != _current) setState(() => _current = tab);
  }

  void _setGlobalLoading(bool loading, {String? label, required MainTab tab}) {
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
    final tabs = MainTab.values;
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
            _select(MainTab.closet);
          },
        );
      case QuickAction.addOutfit:
        await openAddOutfit(context, ref);
      case QuickAction.newTrip:
        await handleCreateTrip(
          context,
          ref,
          onCreated: () => _select(MainTab.tripPlanner),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      selectTab: _select,
      setLoading: _setGlobalLoading,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleSwipe,
            child: IndexedStack(
              index: MainTab.values.indexOf(_current),
              children: const [
                HomePage(),
                ClosetPage(),
                OutfitsPage(),
                TripsPage(),
              ],
            ),
          ),
          MainNavBar(
            current: _current,
            onSelect: _select,
            onQuickAction: _handleQuickAction,
          ),
          // Painted last so it also covers MainNavBar.
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
    builder: (_) =>
        LoadingOverlay(label: AppLocalizations.of(context).loadingGarments),
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
