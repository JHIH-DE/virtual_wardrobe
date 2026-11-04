import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/accent_pill_button.dart';
import '../../widgets/common/buttons/settings_button.dart';

/// `ExploreShell`'s first tab, mirroring Home: brand title, a
/// "Wardrobe" pill back to `WardrobeShell`, Settings. The body is empty for now.
class ExploreHomePage extends StatelessWidget {
  const ExploreHomePage({super.key});

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
        actions: const [SettingsButton()],
      ),
      body: const SizedBox.shrink(),
    );
  }
}
