import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/buttons/action_disc_button.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/explore_nav_bar.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';

/// Discovery feed pushed from Home's "Explore" pill, with its own
/// [ExploreNavBar]. Content is a placeholder; only the chrome is wired up.
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
          style: AppTextStyle.brandTitleToolbar,
        ),
        showBackButton: false,
        leadingWidth: 136,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AccentPillButton(
              label: l10n.navHome,
              icon: Icons.home_outlined,
              variant: AccentPillButtonVariant.toolbar,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [_NotificationsButton()],
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

/// Visual only — there's no notifications screen yet.
class _NotificationsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).notifications,
      child: ActionDiscButton(
        icon: const Icon(
          Icons.notifications_none,
          size: ActionDisc.iconSize,
          color: AppColors.icon,
        ),
        onPressed: () {},
      ),
    );
  }
}
