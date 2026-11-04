import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';

/// `ExploreShell`'s Inbox tab. Empty for now.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(
        title: AppLocalizations.of(context).exploreNavInbox,
        centerTitle: false,
        showBackButton: false,
      ),
      body: const SizedBox.shrink(),
    );
  }
}
