import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

import '../../../app/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/fields/app_search_bar.dart';

/// `ExploreShell`'s Search tab. No results yet.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _queryCtrl = TextEditingController();

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(
        title: _l10n.exploreNavSearch,
        titleSpacing: 4,
        titleWidget: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: AppSearchBar(
            controller: _queryCtrl,
            hint: _l10n.exploreNavSearch,
            height: ActionDisc.size,
            showClearButton: false,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
        showBackButton: false,
        centerTitle: false,
        actions: [
          if (_queryCtrl.text.isEmpty)
            // Visual only — no camera search yet.
            ActionDiscButton(
              icon: const Icon(
                LucideIcons400.camera,
                size: ActionDisc.iconSize,
                color: AppColors.icon,
              ),
              onPressed: () {},
            )
          else
            ActionDiscButton(
              tooltip: _l10n.clear,
              icon: const Icon(
                Icons.close,
                size: ActionDisc.iconSize,
                color: AppColors.icon,
              ),
              onPressed: _clearQuery,
            ),
        ],
      ),
      body: const SizedBox.shrink(),
    );
  }

  void _clearQuery() {
    _queryCtrl.clear();
    setState(() {});
  }
}
