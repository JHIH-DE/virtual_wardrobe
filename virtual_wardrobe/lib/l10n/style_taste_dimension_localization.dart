import 'package:flutter/widgets.dart';

import '../data/style_taste.dart';
import 'generated/app_localizations.dart';

extension StyleTasteDimensionLocalization on StyleTasteDimension {
  String title(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case StyleTasteDimension.styleBalance:
        return l10n.styleTasteStyleBalanceTitle;
      case StyleTasteDimension.colorPairing:
        return l10n.styleTasteColorPairingTitle;
      case StyleTasteDimension.fitPreference:
        return l10n.styleTasteFitPreferenceTitle;
      case StyleTasteDimension.layering:
        return l10n.styleTasteLayeringTitle;
      case StyleTasteDimension.accessories:
        return l10n.styleTasteAccessoriesTitle;
    }
  }

  /// The pole label to show for a given [score] (0.0-1.0) — the low pole's
  /// name below the midpoint, the high pole's name at/above it.
  String poleLabel(BuildContext context, double score) =>
      score >= 0.5 ? highLabel(context) : lowLabel(context);

  String lowLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case StyleTasteDimension.styleBalance:
        return l10n.styleTasteStyleBalanceLow;
      case StyleTasteDimension.colorPairing:
        return l10n.styleTasteColorPairingLow;
      case StyleTasteDimension.fitPreference:
        return l10n.styleTasteFitPreferenceLow;
      case StyleTasteDimension.layering:
        return l10n.styleTasteLayeringLow;
      case StyleTasteDimension.accessories:
        return l10n.styleTasteAccessoriesLow;
    }
  }

  String highLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case StyleTasteDimension.styleBalance:
        return l10n.styleTasteStyleBalanceHigh;
      case StyleTasteDimension.colorPairing:
        return l10n.styleTasteColorPairingHigh;
      case StyleTasteDimension.fitPreference:
        return l10n.styleTasteFitPreferenceHigh;
      case StyleTasteDimension.layering:
        return l10n.styleTasteLayeringHigh;
      case StyleTasteDimension.accessories:
        return l10n.styleTasteAccessoriesHigh;
    }
  }
}
