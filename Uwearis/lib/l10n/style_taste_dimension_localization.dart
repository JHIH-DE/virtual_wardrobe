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

  /// Low pole below 0.5, high pole at/above it.
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

  /// Static, same-for-everyone explanation for the "What these mean" dialog
  /// (unlike the API's per-user [StyleTastePreference.description]).
  String explanation(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case StyleTasteDimension.styleBalance:
        return l10n.styleTasteStyleBalanceExplanation;
      case StyleTasteDimension.colorPairing:
        return l10n.styleTasteColorPairingExplanation;
      case StyleTasteDimension.fitPreference:
        return l10n.styleTasteFitPreferenceExplanation;
      case StyleTasteDimension.layering:
        return l10n.styleTasteLayeringExplanation;
      case StyleTasteDimension.accessories:
        return l10n.styleTasteAccessoriesExplanation;
    }
  }
}
