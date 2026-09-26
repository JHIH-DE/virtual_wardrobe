import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/overlays/error_dialog.dart';

/// Debug-only screen for previewing UI states that are otherwise hard to
/// trigger on demand (e.g. the dialog shown for an unrecoverable backend
/// error). Only reachable from Settings when [kDebugMode] is true — see
/// `settings_page.dart`'s `_buildDebugToolsCard`.
class DebugToolsPage extends StatelessWidget {
  const DebugToolsPage({super.key});

  void _showSampleErrorDialog(BuildContext context, AppLocalizations l10n) {
    showErrorDialog(context, message: l10n.debugToolsSampleErrorMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(title: l10n.debugTools),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppListCard(
            onTap: () => _showSampleErrorDialog(context, l10n),
            leading: const Icon(
              Icons.error_outline,
              color: AppColors.icon,
            ),
            summary: l10n.debugToolsErrorDialogSummary,
            child: Text(
              l10n.debugToolsErrorDialogButton,
              style: AppTextStyle.bold16,
            ),
          ),
          const SizedBox(height: AppDimens.sectionSpacing),
        ],
      ),
    );
  }
}
