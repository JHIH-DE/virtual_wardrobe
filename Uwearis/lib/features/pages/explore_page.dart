import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/action_disc_button.dart';

/// `ExploreShell`'s first tab, mirroring Home: brand title, a
/// "Wardrobe" pill back to `MainShell`, notifications. The body is empty for now.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              label: l10n.wardrobe,
              variant: AccentPillButtonVariant.toolbar,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [_NotificationsButton()],
      ),
      body: const SizedBox.shrink(),
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
