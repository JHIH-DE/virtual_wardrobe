import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'nav_bar_tab.dart';
import 'pressed_state_mixin.dart';

enum MainTab { home, closet, outfits, tripPlanner }

enum QuickAction { addClothing, addOutfit, newTrip }

/// Lets a descendant page switch `MainShell`'s tab or show its loading
/// overlay.
class MainShellScope extends InheritedWidget {
  final ValueChanged<MainTab> selectTab;

  /// A shell-level overlay, since a tab body sits below [MainNavBar] and
  /// can't cover it. Shown only while [tab] is active — every tab stays
  /// mounted, so a background tab's fetch must not mask the screen.
  final void Function(bool loading, {String? label, required MainTab tab})
  setLoading;

  const MainShellScope({
    super.key,
    required this.selectTab,
    required this.setLoading,
    required super.child,
  });
  static MainShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShellScope>();

  @override
  bool updateShouldNotify(MainShellScope oldWidget) =>
      selectTab != oldWidget.selectTab || setLoading != oldWidget.setLoading;
}

/// Floating bottom nav bar with a raised center quick-action button.
/// Presentational only; the host handles [onSelect] / [onQuickAction].
class MainNavBar extends StatefulWidget {
  final MainTab current;
  final ValueChanged<MainTab> onSelect;
  final ValueChanged<QuickAction> onQuickAction;

  const MainNavBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onQuickAction,
  });

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  static const double _centerButtonSize = 56;
  static const double _notchRadius = 34;
  static const double _cornerRadius = 28;

  /// Only Home opens a menu; other tabs fire their action directly.
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          // The spacer keeps the button inside the Stack's bounds — a
          // negative offset would leave its top half untappable.
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
                    color: Colors.transparent,
                    elevation: 8,
                    shadowColor: AppColors.trueBlack,
                    // PhysicalShape's clip doesn't confine a
                    // BackdropFilter; without this ClipPath the blur covers
                    // the whole screen.
                    child: ClipPath(
                      clipper: const _NotchedBarClipper(
                        cornerRadius: _cornerRadius,
                        notchRadius: _notchRadius,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          color: AppColors.scrimBackdrop,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              type: MaterialType.transparency,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _tab(
                                    MainTab.home,
                                    activeIcon: Icons.home_rounded,
                                    inactiveIcon: Icons.home_outlined,
                                    label: l10n.navHome,
                                  ),
                                  _tab(
                                    MainTab.closet,
                                    activeIcon: Icons.checkroom_rounded,
                                    inactiveIcon: Icons.checkroom_outlined,
                                    label: l10n.navCloset,
                                  ),
                                  const SizedBox(width: _centerButtonSize),
                                  _tab(
                                    MainTab.outfits,
                                    activeIcon: Icons.style_rounded,
                                    inactiveIcon: Icons.style_outlined,
                                    label: l10n.navOutfits,
                                  ),
                                  _tab(
                                    MainTab.tripPlanner,
                                    activeIcon: Icons.luggage_rounded,
                                    inactiveIcon: Icons.luggage_outlined,
                                    label: l10n.navTrips,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    MainTab tab, {
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    return NavBarTab(
      activeIcon: activeIcon,
      inactiveIcon: inactiveIcon,
      label: label,
      isActive: tab == widget.current,
      onTap: () => widget.onSelect(tab),
    );
  }

  Widget _buildQuickActionButton(BuildContext context) {
    final showClose = widget.current == MainTab.home && _menuOpen;
    return _QuickActionButton(
      size: _centerButtonSize,
      icon: showClose ? Icons.close : Icons.add,
      // Icons.close fills its bounds more than Icons.add, so it reads bigger.
      iconSize: showClose ? 30 : 34,
      onTap: () => _handleQuickActionTap(context),
    );
  }

  /// Non-Home tabs imply their action; only Home shows the menu.
  void _handleQuickActionTap(BuildContext context) {
    final directAction = switch (widget.current) {
      MainTab.closet => QuickAction.addClothing,
      MainTab.outfits => QuickAction.addOutfit,
      MainTab.tripPlanner => QuickAction.newTrip,
      MainTab.home => null,
    };
    if (directAction != null) {
      widget.onQuickAction(directAction);
    } else {
      _showQuickActionMenu(context);
    }
  }

  Future<void> _showQuickActionMenu(BuildContext context) async {
    setState(() => _menuOpen = true);
    final l10n = AppLocalizations.of(context);
    final action = await showGeneralDialog<QuickAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.quickActions,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Material(
              color: AppColors.scrimBackdrop,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.dividerOnDark),
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quickActionItem(
                      context,
                      value: QuickAction.addClothing,
                      label: l10n.quickActionAddClothing,
                      icon: Icons.dry_cleaning_outlined,
                      showDivider: true,
                    ),
                    _quickActionItem(
                      context,
                      value: QuickAction.addOutfit,
                      label: l10n.quickActionAddOutfit,
                      icon: Icons.accessibility_new_outlined,
                      showDivider: true,
                    ),
                    _quickActionItem(
                      context,
                      value: QuickAction.newTrip,
                      label: l10n.newTrip,
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
    if (mounted) setState(() => _menuOpen = false);
    if (action != null) widget.onQuickAction(action);
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.dividerOnDark, width: 1),
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textOnPrimary),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyle.regular16.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final double size;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with PressedStateMixin<_QuickActionButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setPressed(true),
      onTapUp: (_) => setPressed(false),
      onTapCancel: () => setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderOnDark, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.overlaySubtle,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: AppColors.textOnPrimary,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}

/// Rounded rect with a top-center notch for the raised button.
/// [CircularNotchedRectangle] avoids the sharp cusps a plain
/// rect-minus-circle would leave.
class _NotchedBarClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchRadius;

  const _NotchedBarClipper({
    required this.cornerRadius,
    required this.notchRadius,
  });

  @override
  Path getClip(Size size) {
    final host = Rect.fromLTWH(0, 0, size.width, size.height);
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, 0),
      radius: notchRadius,
    );
    final smoothNotchedPath = const CircularNotchedRectangle().getOuterPath(
      host,
      guest,
    );
    final roundedCornersPath = Path()
      ..addRRect(RRect.fromRectAndRadius(host, Radius.circular(cornerRadius)));
    return Path.combine(
      PathOperation.intersect,
      smoothNotchedPath,
      roundedCornersPath,
    );
  }

  @override
  bool shouldReclip(covariant _NotchedBarClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius ||
      oldClipper.notchRadius != notchRadius;
}
