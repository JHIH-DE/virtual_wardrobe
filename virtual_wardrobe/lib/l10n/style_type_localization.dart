import 'package:flutter/widgets.dart';

import '../data/style_type.dart';
import 'generated/app_localizations.dart';

extension StyleTypeLocalization on StyleType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case StyleType.minimal:
        return l10n.styleMinimal;
      case StyleType.classic:
        return l10n.styleClassic;
      case StyleType.smartCasual:
        return l10n.styleSmartCasual;
      case StyleType.streetwear:
        return l10n.styleStreetwear;
      case StyleType.athleisure:
        return l10n.styleAthleisure;
      case StyleType.workwear:
        return l10n.styleWorkwear;
      case StyleType.preppy:
        return l10n.stylePreppy;
      case StyleType.business:
        return l10n.styleBusiness;
      case StyleType.vintage:
        return l10n.styleVintage;
    }
  }
}
