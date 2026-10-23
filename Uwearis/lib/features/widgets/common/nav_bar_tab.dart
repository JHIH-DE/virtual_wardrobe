import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// One tab of the frosted bottom nav bars ([MainNavBar], [ExploreNavBar]).
/// Must sit flush with the bar's top edge so the active marker hangs from it.
class NavBarTab extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double horizontalPadding;

  const NavBarTab({
    super.key,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.horizontalPadding = 6,
  });

  static const double _markerHeight = 5;
  static const double _markerWidth = 24;
  static const double _iconTopGap = 7;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.textOnPrimary : AppColors.navBarInactive;
    return Semantics(
      selected: isActive,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: isActive ? _markerWidth : 0,
                height: _markerHeight,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(_markerHeight),
                  ),
                ),
              ),
              const SizedBox(height: _iconTopGap),
              Icon(
                isActive ? activeIcon : inactiveIcon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyle.regular12.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
