import 'package:flutter/material.dart';

import '../../finance_page.dart';
import '../../looks_page.dart';
import '../../my_closet_page.dart';

enum AppTab { home, closet, looks, finance }

/// Floating rounded nav bar shown on the app's main tabs (Home, My Closet,
/// Looks, Finance). Highlights [current] so the user always knows which
/// page they're on, and jumps directly to any other tab from anywhere.
class FloatingNavBar extends StatelessWidget {
  final AppTab current;

  const FloatingNavBar({super.key, required this.current});

  /// Tapping Home pops back to the app's root; every other tab resets the
  /// stack to [root page, target page] so hopping between tabs repeatedly
  /// can't pile up an ever-growing back stack.
  void _goTo(BuildContext context, AppTab tab) {
    if (tab == current) return;
    if (tab == AppTab.home) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    final Widget page = switch (tab) {
      AppTab.closet => const MyClosetPage(),
      AppTab.looks => const LooksPage(),
      AppTab.finance => const FinancePage(),
      AppTab.home => const SizedBox.shrink(),
    };
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => route.isFirst,
    );
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
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
                    context,
                    AppTab.home,
                    activeIcon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                  ),
                  const SizedBox(width: 20),
                  _tab(
                    context,
                    AppTab.closet,
                    activeIcon: Icons.checkroom_rounded,
                    inactiveIcon: Icons.checkroom_outlined,
                  ),
                  const SizedBox(width: 20),
                  _tab(
                    context,
                    AppTab.looks,
                    activeIcon: Icons.style_rounded,
                    inactiveIcon: Icons.style_outlined,
                  ),
                  const SizedBox(width: 20),
                  _tab(
                    context,
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
    BuildContext context,
    AppTab tab, {
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final isActive = tab == current;
    return InkWell(
      onTap: () => _goTo(context, tab),
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? Colors.black : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
