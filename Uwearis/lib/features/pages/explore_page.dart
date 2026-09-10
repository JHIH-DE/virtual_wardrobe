import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/explore_nav_bar.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';

/// Discovery feed reached from Home's "Explore" pill. Pushed on top of the
/// tab shell (not a tab itself), so its toolbar mirrors Home's — brand title
/// centred, a leading pill and a trailing action — but the pill points back
/// *to* Home and the trailing action is a notifications bell rather than the
/// settings gear. Carries its own [ExploreNavBar] (five tabs, no center
/// button) instead of the main [MainNavBar].
///
/// Content is a placeholder for now; only the chrome is wired up.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  ExploreTab _current = ExploreTab.forYou;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final bottomClearance =
        AppDimens.mainNavBarClearance + MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(
        title: l10n.explore,
        titleWidget: Text(
          'Uwearis',
          textScaler: TextScaler.noScaling,
          style: AppTextStyle.brandTitle,
        ),
        showBackButton: false,
        leadingWidth: 128,
        leading: Padding(
          // Matches Home's leading pill inset.
          padding: const EdgeInsets.only(left: 16),
          // centerLeft, not Center: the leading slot is wider than the pill,
          // so a plain Center would float a shorter label ("Home") further
          // right than a longer one — anchor the left edge instead so it
          // lines up with Home's pill regardless of label width.
          child: Align(
            alignment: Alignment.centerLeft,
            child: AccentPillButton(
              label: l10n.navHome,
              icon: Icons.home_outlined,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [_NotificationsButton(), const SizedBox(width: 8)],
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: bottomClearance),
            child: Center(
              child: EmptyStatePlaceholder(
                icon: Icons.explore_outlined,
                message: l10n.exploreComingSoon,
              ),
            ),
          ),
          ExploreNavBar(
            current: _current,
            onSelect: (tab) => setState(() => _current = tab),
          ),
        ],
      ),
    );
  }
}

/// Trailing bell in the Explore toolbar — same touch-target/slot treatment as
/// Home's settings gear. Visual only for now: there's no notifications screen
/// to open yet.
class _NotificationsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).notifications,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppDimens.toolbarHeight / 2),
        child: SizedBox.square(
          dimension: AppDimens.toolbarHeight,
          child: const Center(
            child: Icon(
              Icons.notifications_none,
              size: AppDimens.toolbarActionIconSize,
              color: AppColors.icon,
            ),
          ),
        ),
      ),
    );
  }
}
