import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';

/// `ExploreShell`'s Bag tab. Empty for now.
class BagPage extends StatelessWidget {
  const BagPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(
        title: AppLocalizations.of(context).exploreNavBag,
        centerTitle: false,
        showBackButton: false,
      ),
      body: const SizedBox.shrink(),
    );
  }
}
