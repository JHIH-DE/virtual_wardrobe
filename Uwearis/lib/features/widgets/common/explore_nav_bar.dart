import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'nav_bar_tab.dart';

enum ExploreTab { forYou, search, bag, saved, account }

/// [ExplorePage]'s bottom nav: [MainNavBar]'s frosted pill with five equal
/// tabs and no raised center button. Purely presentational.
class ExploreNavBar extends StatelessWidget {
  final ExploreTab current;
  final ValueChanged<ExploreTab> onSelect;

  const ExploreNavBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  static const double _cornerRadius = 28;

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
          child: PhysicalModel(
            color: Colors.transparent,
            elevation: 8,
            shadowColor: AppColors.trueBlack,
            borderRadius: BorderRadius.circular(_cornerRadius),
            clipBehavior: Clip.antiAlias,
            // PhysicalModel's clip doesn't reliably confine a BackdropFilter
            // descendant, so clip again.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_cornerRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: AppColors.scrimBackdrop,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Row(
                        children: [
                          _tab(
                            ExploreTab.forYou,
                            activeIcon: Icons.auto_awesome,
                            inactiveIcon: Icons.auto_awesome_outlined,
                            label: l10n.exploreNavForYou,
                          ),
                          _tab(
                            ExploreTab.search,
                            activeIcon: Icons.search,
                            inactiveIcon: Icons.search,
                            label: l10n.exploreNavSearch,
                          ),
                          _tab(
                            ExploreTab.bag,
                            activeIcon: Icons.shopping_bag,
                            inactiveIcon: Icons.shopping_bag_outlined,
                            label: l10n.exploreNavBag,
                          ),
                          _tab(
                            ExploreTab.saved,
                            activeIcon: Icons.favorite,
                            inactiveIcon: Icons.favorite_border,
                            label: l10n.exploreNavSaved,
                          ),
                          _tab(
                            ExploreTab.account,
                            activeIcon: Icons.person,
                            inactiveIcon: Icons.person_outline,
                            label: l10n.account,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(
    ExploreTab tab, {
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    return Expanded(
      child: NavBarTab(
        activeIcon: activeIcon,
        inactiveIcon: inactiveIcon,
        label: label,
        isActive: tab == current,
        onTap: () => onSelect(tab),
        horizontalPadding: 2,
      ),
    );
  }
}
