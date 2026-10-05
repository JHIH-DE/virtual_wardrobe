import 'package:flutter/widgets.dart';

import '../data/user_tier.dart';
import 'generated/app_localizations.dart';

extension UserTierLocalization on UserTier {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case UserTier.gold:
        return l10n.tierGold;
      case UserTier.silver:
        return l10n.tierSilver;
      case UserTier.bronze:
        return l10n.tierBronze;
    }
  }
}
