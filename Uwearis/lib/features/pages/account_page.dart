import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';

/// `ExploreShell`'s Account tab. Empty for now.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(
        title: AppLocalizations.of(context).account,
        centerTitle: false,
        showBackButton: false,
      ),
      body: const SizedBox.shrink(),
    );
  }
}
