import 'package:flutter/material.dart';

import '../features/finance_page.dart';
import '../features/home_page.dart';
import '../features/looks_page.dart';
import '../features/my_closet_page.dart';
import '../features/trip_planner_page.dart';
import '../features/widgets/common/floating_nav_bar.dart';

/// Persistent shell hosting the app's 5 main tabs (Home, My Closet, Looks,
/// Trip Planner, Finance) in an [IndexedStack]. Unlike pushing each tab as
/// its own route, this keeps every tab's widget state (scroll position,
/// in-progress filters, etc.) alive across switches, and the floating nav
/// bar is built once here rather than per-page — so switching tabs is a
/// plain `setState` with no route transition to animate, and the bar
/// never flickers.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
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
                FinancePage(),
              ],
            ),
          ),
          FloatingNavBar(current: _current, onSelect: _select),
        ],
      ),
    );
  }
}
