import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/utils/debug_log.dart';
import '../features/pages/add_outfit_page.dart';
import '../features/pages/closet_page.dart';
import '../features/pages/home_page.dart';
import '../features/pages/outfits_page.dart';
import '../features/pages/trips_page.dart';
import '../features/widgets/common/floating_nav_bar.dart';
import '../features/widgets/common/overlays/loading_overlay.dart';
import '../features/widgets/garment/garment_upload_helper.dart';
import '../l10n/generated/app_localizations.dart';

/// Persistent shell hosting the app's 4 main tabs (Home, My Closet, Outfits,
/// Trips) in an [IndexedStack]. Unlike pushing each tab as its own
/// route, this keeps every tab's widget state (scroll position, in-progress
/// filters, etc.) alive across switches, and the floating nav bar is built
/// once here rather than per-page — so switching tabs is a plain `setState`
/// with no route transition to animate, and the bar never flickers.
///
/// Also owns the nav bar's raised center button (add clothing / add outfit /
/// new trip) — it lives here rather than on a single page since it needs
/// to work the same regardless of which tab is active.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  AppTab _current = AppTab.home;
  // Every tab stays mounted in the IndexedStack below, so each one's own
  // background fetch (garments, outfits, trips) reports its loading state
  // independently — keyed by tab here so a hidden tab's fetch never shows
  // the shell-level overlay over whichever tab the user is actually
  // looking at (see MainShellScope.setLoading).
  final Map<AppTab, String?> _loadingLabelByTab = {};

  void _select(AppTab tab) {
    if (tab != _current) setState(() => _current = tab);
  }

  void _setGlobalLoading(bool loading, {String? label, required AppTab tab}) {
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

  /// Swiping left/right cycles to the next/previous tab in [AppTab.values]
  /// order, wrapping around. Handled once here (rather than per-page) so
  /// every tab gets the gesture for free.
  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 200.0;
    final tabs = AppTab.values;
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
            // Land on My Closet regardless of which tab the quick action
            // was triggered from.
            _select(AppTab.closet);
          },
        );
      case QuickAction.addOutfit:
        await _openAddOutfit();
      case QuickAction.newTrip:
        await handleCreateTrip(context, ref);
    }
  }

  Future<void> _openAddOutfit() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) =>
          LoadingOverlay(label: AppLocalizations.of(context).loadingGarments),
    );
    try {
      final garments = await ref.read(garmentsProvider.future);
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddOutfitPage(
            preloadedGarments: garments,
            onBack: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      debugLog('Failed to load garments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToLoadGarments),
        ),
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
              index: AppTab.values.indexOf(_current),
              children: const [
                HomePage(),
                ClosetPage(),
                OutfitsPage(),
                TripsPage(),
              ],
            ),
          ),
          FloatingNavBar(
            current: _current,
            onSelect: _select,
            onQuickAction: _handleQuickAction,
          ),
          // Painted last so it sits above FloatingNavBar and truly covers
          // the whole screen — see MainShellScope.setLoading. Only the
          // *currently active* tab's loading state can trigger this, even
          // though every tab reports its own independently.
          if (_loadingLabelByTab[_current] != null)
            LoadingOverlay(label: _loadingLabelByTab[_current]!),
        ],
      ),
    );
  }
}
