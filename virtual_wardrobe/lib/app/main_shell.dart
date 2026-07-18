import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/utils/debug_log.dart';
import '../features/home_page.dart';
import '../features/looks_page.dart';
import '../features/add_look_page.dart';
import '../features/my_closet_page.dart';
import '../features/trip_planner_page.dart';
import '../features/widgets/common/floating_nav_bar.dart';
import '../features/widgets/common/loading_overlay.dart';
import '../features/widgets/garment/garment_upload_helper.dart';

/// Persistent shell hosting the app's 4 main tabs (Home, My Closet, Looks,
/// Trip Planner) in an [IndexedStack]. Unlike pushing each tab as its own
/// route, this keeps every tab's widget state (scroll position, in-progress
/// filters, etc.) alive across switches, and the floating nav bar is built
/// once here rather than per-page — so switching tabs is a plain `setState`
/// with no route transition to animate, and the bar never flickers.
///
/// Also owns the nav bar's raised center button (add clothing / add look /
/// new trip) — it lives here rather than on a single page since it needs
/// to work the same regardless of which tab is active.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  AppTab _current = AppTab.home;

  void _select(AppTab tab) {
    if (tab != _current) setState(() => _current = tab);
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
          onAdded: (g) => ref.read(garmentsProvider.notifier).addGarment(g),
        );
      case QuickAction.addLook:
        await _openAddLook();
      case QuickAction.newTrip:
        await handleCreateTrip(context, ref);
    }
  }

  Future<void> _openAddLook() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => const LoadingOverlay(label: 'Loading Garments...'),
    );
    try {
      final garments = await ref.read(garmentsProvider.future);
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddLookPage(
            preloadedGarments: garments,
            onBack: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading indicator
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load garments: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load garments')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      selectTab: _select,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleSwipe,
            child: IndexedStack(
              index: AppTab.values.indexOf(_current),
              children: const [
                HomePage(),
                MyClosetPage(),
                LooksPage(),
                TripPlannerPage(),
              ],
            ),
          ),
          FloatingNavBar(
            current: _current,
            onSelect: _select,
            onQuickAction: _handleQuickAction,
          ),
        ],
      ),
    );
  }
}
