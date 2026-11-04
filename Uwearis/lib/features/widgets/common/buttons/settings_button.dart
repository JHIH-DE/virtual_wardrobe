import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../pages/settings/settings_page.dart';
import 'action_disc_button.dart';

/// The toolbar action that opens Settings.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ActionDiscButton(
      tooltip: AppLocalizations.of(context).settings,
      icon: Image.asset(
        'assets/images/setting.png',
        height: ActionDisc.iconSize,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
    );
  }
}
