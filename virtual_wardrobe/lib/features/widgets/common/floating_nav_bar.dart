import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

enum AppTab { home, closet, looks, tripPlanner, finance }

/// Lets any descendant page switch the active tab in the persistent
/// `MainShell` above it — e.g. after creating a trip, jump to the Trip
/// Planner tab so "back" lands there instead of wherever the creation flow
/// was started from.
class MainShellScope extends InheritedWidget {
  final ValueChanged<AppTab> selectTab;

  const MainShellScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  static MainShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShellScope>();

  @override
  bool updateShouldNotify(MainShellScope oldWidget) =>
      selectTab != oldWidget.selectTab;
}

/// Floating rounded nav bar shown on the app's main tabs (Home, My Closet,
/// Looks, Trip Planner, Finance). Highlights [current] so the user always
/// knows which page they're on. Purely presentational — [onSelect] is
/// called with the tapped tab and the host (e.g. a persistent IndexedStack
/// shell) decides how to switch to it.
class FloatingNavBar extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  const FloatingNavBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.scrimBackdrop,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tab(
                    AppTab.home,
                    activeIcon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                  ),
                  const SizedBox(width: 16),
                  _tab(
                    AppTab.closet,
                    activeIcon: Icons.checkroom_rounded,
                    inactiveIcon: Icons.checkroom_outlined,
                  ),
                  const SizedBox(width: 16),
                  _tab(
                    AppTab.looks,
                    activeIcon: Icons.style_rounded,
                    inactiveIcon: Icons.style_outlined,
                  ),
                  const SizedBox(width: 16),
                  _tab(
                    AppTab.tripPlanner,
                    activeIcon: Icons.luggage_rounded,
                    inactiveIcon: Icons.luggage_outlined,
                  ),
                  const SizedBox(width: 16),
                  _tab(
                    AppTab.finance,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    inactiveIcon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(
    AppTab tab, {
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final isActive = tab == current;
    return InkWell(
      onTap: () => onSelect(tab),
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          // inactive icon stays light — it sits on the dark frosted pill background
          color: isActive ? AppColors.icon : AppColors.textOnPrimary,
          size: 24,
        ),
      ),
    );
  }
}
