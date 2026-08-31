import 'package:flutter/widgets.dart';

import '../data/occasion_type.dart';
import 'generated/app_localizations.dart';

extension OccasionTypeLocalization on OccasionType {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case OccasionType.work:
        return l10n.occasionWork;
      case OccasionType.casual:
        return l10n.occasionCasual;
      case OccasionType.workout:
        return l10n.occasionWorkout;
      case OccasionType.date:
        return l10n.occasionDate;
      case OccasionType.travel:
        return l10n.occasionTravel;
      case OccasionType.party:
        return l10n.occasionParty;
    }
  }
}
