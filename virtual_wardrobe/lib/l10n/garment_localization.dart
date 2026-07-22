import 'package:flutter/widgets.dart';

import '../data/garment.dart';
import 'generated/app_localizations.dart';

extension GarmentCategoryLocalization on GarmentCategory {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case GarmentCategory.top:
        return l10n.categoryTop;
      case GarmentCategory.bottom:
        return l10n.categoryBottom;
      case GarmentCategory.outer:
        return l10n.categoryOuter;
      case GarmentCategory.onePiece:
        return l10n.categoryOnePiece;
      case GarmentCategory.socks:
        return l10n.categorySocks;
      case GarmentCategory.shoes:
        return l10n.categoryShoes;
      case GarmentCategory.accessory:
        return l10n.categoryAccessory;
    }
  }
}

extension GarmentColorLocalization on GarmentColor {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case GarmentColor.black:
        return l10n.colorBlack;
      case GarmentColor.white:
        return l10n.colorWhite;
      case GarmentColor.grey:
        return l10n.colorGrey;
      case GarmentColor.beige:
        return l10n.colorBeige;
      case GarmentColor.cream:
        return l10n.colorCream;
      case GarmentColor.brown:
        return l10n.colorBrown;
      case GarmentColor.navy:
        return l10n.colorNavy;
      case GarmentColor.blue:
        return l10n.colorBlue;
      case GarmentColor.green:
        return l10n.colorGreen;
      case GarmentColor.olive:
        return l10n.colorOlive;
      case GarmentColor.khaki:
        return l10n.colorKhaki;
      case GarmentColor.red:
        return l10n.colorRed;
      case GarmentColor.burgundy:
        return l10n.colorBurgundy;
      case GarmentColor.yellow:
        return l10n.colorYellow;
      case GarmentColor.orange:
        return l10n.colorOrange;
      case GarmentColor.pink:
        return l10n.colorPink;
      case GarmentColor.purple:
        return l10n.colorPurple;
    }
  }
}
