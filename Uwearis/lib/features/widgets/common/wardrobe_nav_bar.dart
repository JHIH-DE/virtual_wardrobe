import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'nav_bar_tab.dart';
import 'points_amount.dart';
import 'pressed_state_mixin.dart';

enum WardrobeTab { home, closet, outfits, tripPlanner }

enum QuickAction { addClothing, addOutfit, newTrip }

/// Lets a descendant page switch `WardrobeShell`'s tab or show its loading
/// overlay.
class WardrobeShellScope extends InheritedWidget {
  final ValueChanged<WardrobeTab> selectTab;

  /// A shell-level overlay, since a tab body sits below [WardrobeNavBar] and
  /// can't cover it. Shown only while [tab] is active — every tab stays
  /// mounted, so a background tab's fetch must not mask the screen.
  final void Function(bool loading, {String? label, required WardrobeTab tab})
  setLoading;

  const WardrobeShellScope({
    super.key,
    required this.selectTab,
    required this.setLoading,
    required super.child,
  });
  static WardrobeShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WardrobeShellScope>();

  @override
  bool updateShouldNotify(WardrobeShellScope oldWidget) =>
      selectTab != oldWidget.selectTab || setLoading != oldWidget.setLoading;
}

/// Floating bottom nav bar with a raised center quick-action button.
/// Presentational only; the host handles [onSelect] / [onQuickAction].
class WardrobeNavBar extends StatefulWidget {
  final WardrobeTab current;
  final ValueChanged<WardrobeTab> onSelect;
  final ValueChanged<QuickAction> onQuickAction;

  /// The user's points balance, shown under the center button; null while
  /// it hasn't loaded (the slot stays reserved).
  final int? credits;

  const WardrobeNavBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onQuickAction,
    this.credits,
  });

  @override
  State<WardrobeNavBar> createState() => _WardrobeNavBarState();
}

class _WardrobeNavBarState extends State<WardrobeNavBar> {
  static const double _centerButtonSize = 56;
  static const double _notchRadius = 34;

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
                  NavBarGlass(
                    clipper: const _NotchedBarClipper(
                      notchRadius: _notchRadius,
                    ),
                    child: NavBarTabRow(
                      children: [
                        _tab(
                          WardrobeTab.home,
                          activeIcon: Icons.home_rounded,
                          inactiveIcon: Icons.home_outlined,
                          label: l10n.navHome,
                        ),
                        _tab(
                          WardrobeTab.closet,
                          activeIcon: Icons.checkroom_rounded,
                          inactiveIcon: Icons.checkroom_outlined,
                          label: l10n.navCloset,
                        ),
                        SizedBox(
                          width: _CreditsBalance.slotWidthFor(
                            context,
                            minWidth: _centerButtonSize,
                          ),
                          height: NavBarTab.heightFor(context),
                          child: widget.credits == null
                              ? null
                              : _CreditsBalance(credits: widget.credits!),
                        ),
                        _tab(
                          WardrobeTab.outfits,
                          activeIcon: Icons.style_rounded,
                          inactiveIcon: Icons.style_outlined,
                          label: l10n.navOutfits,
                        ),
                        _tab(
                          WardrobeTab.tripPlanner,
                          activeIcon: Icons.luggage_rounded,
                          inactiveIcon: Icons.luggage_outlined,
                          label: l10n.navTrips,
                        ),
                      ],
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
    WardrobeTab tab, {
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
    final showClose = widget.current == WardrobeTab.home && _menuOpen;
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
      WardrobeTab.closet => QuickAction.addClothing,
      WardrobeTab.outfits => QuickAction.addOutfit,
      WardrobeTab.tripPlanner => QuickAction.newTrip,
      WardrobeTab.home => null,
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
            child: NavBarGlass(
              clipper: const ShapeBorderClipper(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
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
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.icon),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyle.medium16.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The AI credit balance on the tabs' label line, under the center button.
class _CreditsBalance extends StatelessWidget {
  final int credits;

  const _CreditsBalance({required this.credits});

  /// The slot is sized for this (the backend's grant cap), so the tabs
  /// don't shift as the balance changes.
  static const _maxCredits = 30000;

  static TextSpan _span(BuildContext context, int amount) {
    return TextSpan(
      style: NavBarTab.labelStyle.copyWith(color: AppColors.textSecondary),
      children: [PointsAmount.span(context, amount)],
    );
  }

  /// At least [minWidth], and wide enough for [_maxCredits] at [context]'s
  /// text scale.
  static double slotWidthFor(BuildContext context, {required double minWidth}) {
    final painter = TextPainter(
      text: _span(context, _maxCredits),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return math.max(minWidth, width);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final amount = NumberFormat.decimalPattern(l10n.localeName).format(credits);
    return Semantics(
      label: '${l10n.aiCreditsLabel} $amount',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: NavBarTab.labelBottomPadding),
          child: Text.rich(
            _span(context, credits),
            maxLines: 1,
            softWrap: false,
          ),
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
/// A stadium (fully round ends) with the center button's notch cut out.
class _NotchedBarClipper extends CustomClipper<Path> {
  final double notchRadius;

  const _NotchedBarClipper({required this.notchRadius});

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
      ..addRRect(
        RRect.fromRectAndRadius(host, Radius.circular(size.height / 2)),
      );
    return Path.combine(
      PathOperation.intersect,
      smoothNotchedPath,
      roundedCornersPath,
    );
  }

  @override
  bool shouldReclip(covariant _NotchedBarClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius;
}
