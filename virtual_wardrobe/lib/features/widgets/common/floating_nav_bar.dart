import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

enum AppTab { home, closet, looks, tripPlanner }

/// The three actions behind the nav bar's raised center button.
enum QuickAction { addClothing, addLook, newTrip }

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

/// Floating bottom nav bar shown on the app's main tabs (Home, My Closet,
/// Looks, Trip Planner), with a raised center button for the add-clothing /
/// manual-try-on / new-trip quick actions. Highlights [current] so the user
/// always knows which page they're on. Purely presentational — [onSelect]
/// and [onQuickAction] are called with the tapped tab/action and the host
/// (e.g. a persistent IndexedStack shell) decides what to do with them.
class FloatingNavBar extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final ValueChanged<QuickAction> onQuickAction;

  const FloatingNavBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onQuickAction,
  });

  static const double _centerButtonSize = 56;
  static const double _notchRadius = 34;
  static const double _cornerRadius = 28;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          // The bar sits below a blank spacer reserving room for the
          // center button's top half, so the Stack's own bounds fully
          // contain the button — a plain negative `top` offset here would
          // let the button paint outside the Stack via Clip.none, but
          // hit-testing always stops at a RenderBox's own `size`, so the
          // portion poking out above would silently be untappable.
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: _centerButtonSize / 2),
                  PhysicalShape(
                    clipper: const _NotchedBarClipper(
                      cornerRadius: _cornerRadius,
                      notchRadius: _notchRadius,
                    ),
                    color: AppColors.scrimBackdrop,
                    elevation: 8,
                    shadowColor: Colors.black,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 10),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tab(
                              AppTab.home,
                              activeIcon: Icons.home_rounded,
                              inactiveIcon: Icons.home_outlined,
                              label: 'Home',
                            ),
                            _tab(
                              AppTab.closet,
                              activeIcon: Icons.checkroom_rounded,
                              inactiveIcon: Icons.checkroom_outlined,
                              label: 'Closet',
                            ),
                            const SizedBox(width: _centerButtonSize),
                            _tab(
                              AppTab.looks,
                              activeIcon: Icons.style_rounded,
                              inactiveIcon: Icons.style_outlined,
                              label: 'Looks',
                            ),
                            _tab(
                              AppTab.tripPlanner,
                              activeIcon: Icons.luggage_rounded,
                              inactiveIcon: Icons.luggage_outlined,
                              label: 'Trips',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                child: Material(
                  type: MaterialType.transparency,
                  child: _buildQuickActionButton(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(
    AppTab tab, {
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final isActive = tab == current;
    final color = isActive ? AppColors.accent : AppColors.textOnPrimary;
    return InkWell(
      onTap: () => onSelect(tab),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : inactiveIcon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyle.regular12.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(BuildContext context) {
    return _QuickActionButton(
      size: _centerButtonSize,
      onTap: () => _showQuickActionMenu(context),
    );
  }

  /// Shows the quick-action menu centered horizontally on screen (not
  /// anchored to the button), directly above the nav bar.
  Future<void> _showQuickActionMenu(BuildContext context) async {
    final action = await showGeneralDialog<QuickAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Actions',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 125),
            child: Material(
              color: AppColors.scrimBackdrop,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.dividerOnDark),
              ),
              child: SizedBox(
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quickActionItem(
                      context,
                      value: QuickAction.addClothing,
                      label: 'Add Clothing',
                      icon: Icons.checkroom_outlined,
                      showDivider: true,
                    ),
                    _quickActionItem(
                      context,
                      value: QuickAction.addLook,
                      label: 'Add Look',
                      icon: Icons.accessibility_new_outlined,
                      showDivider: true,
                    ),
                    _quickActionItem(
                      context,
                      value: QuickAction.newTrip,
                      label: 'New Trip',
                      icon: Icons.luggage_outlined,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.0).animate(animation),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
    if (action != null) onQuickAction(action);
  }

  Widget _quickActionItem(
    BuildContext context, {
    required QuickAction value,
    required String label,
    required IconData icon,
    required bool showDivider,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.dividerOnDark, width: 1),
                ),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyle.regular16.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
            Icon(icon, size: 20, color: AppColors.textOnPrimary),
          ],
        ),
      ),
    );
  }
}

/// The nav bar's raised center "+" button — shrinks on press and springs
/// back past full size on release for a tactile, bouncy tap response.
class _QuickActionButton extends StatefulWidget {
  final double size;
  final VoidCallback onTap;

  const _QuickActionButton({required this.size, required this.onTap});

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.overlaySubtle,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: AppColors.textOnPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle with a circular notch bitten out of the top edge,
/// centered horizontally, so the raised center button sits nested into the
/// bar rather than simply stacked on top of it.
class _NotchedBarClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchRadius;

  const _NotchedBarClipper({
    required this.cornerRadius,
    required this.notchRadius,
  });

  @override
  Path getClip(Size size) {
    final barPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(cornerRadius),
        ),
      );
    final notchPath = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(size.width / 2, 0), radius: notchRadius),
      );
    return Path.combine(PathOperation.difference, barPath, notchPath);
  }

  @override
  bool shouldReclip(covariant _NotchedBarClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius ||
      oldClipper.notchRadius != notchRadius;
}
