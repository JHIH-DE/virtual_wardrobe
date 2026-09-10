import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The Explore section's own bottom tabs.
enum ExploreTab { forYou, search, bag, saved, account }

/// Floating bottom nav for [ExplorePage] — the same frosted-glass pill as the
/// main [MainNavBar], but with five evenly-spaced tabs and **no raised
/// center button** (so no notch either). Highlights [current]; purely
/// presentational — [onSelect] is called with the tapped tab and the host
/// decides what to do.
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
            // Frosted glass: blur what's scrolling underneath, then lay the
            // translucent scrim tint over the blur. The inner ClipRRect
            // repeats the rounded-rect clip because a BackdropFilter
            // descendant isn't reliably confined by PhysicalModel's own clip
            // (same Flutter gotcha MainNavBar works around).
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_cornerRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: AppColors.scrimBackdrop,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
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
                            // No filled/outline pair for search — the same
                            // magnifier in both states, colour carries the
                            // active cue.
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
    final isActive = tab == current;
    final color = isActive ? AppColors.accent : AppColors.textOnPrimary;
    // Expanded (not spaceEvenly): five tabs share the width equally, so a
    // two-word label ("For you") gets the same slot as the rest and can
    // centre in it rather than shove its neighbours.
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(tab),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
