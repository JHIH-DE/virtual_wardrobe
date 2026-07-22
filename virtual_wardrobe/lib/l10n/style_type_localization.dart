import 'package:flutter/widgets.dart';

import '../data/style_type.dart';
import 'generated/app_localizations.dart';

extension StyleTypeLocalization on StyleType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case StyleType.minimalist:
        return l10n.styleMinimalist;
      case StyleType.korean:
        return l10n.styleKorean;
      case StyleType.streetwear:
        return l10n.styleStreetwear;
      case StyleType.smartCasual:
        return l10n.styleSmartCasual;
      case StyleType.chic:
        return l10n.styleChic;
      case StyleType.athleisure:
        return l10n.styleAthleisure;
      case StyleType.oldMoney:
        return l10n.styleOldMoney;
      case StyleType.romantic:
        return l10n.styleRomantic;
      case StyleType.vintage:
        return l10n.styleVintage;
      case StyleType.bohemian:
        return l10n.styleBohemian;
      case StyleType.cityBoy:
        return l10n.styleCityBoy;
      case StyleType.americanCasual:
        return l10n.styleAmericanCasual;
      case StyleType.workwear:
        return l10n.styleWorkwear;
      case StyleType.gorpcore:
        return l10n.styleGorpcore;
      case StyleType.techwear:
        return l10n.styleTechwear;
      case StyleType.outdoor:
        return l10n.styleOutdoor;
    }
  }
}
