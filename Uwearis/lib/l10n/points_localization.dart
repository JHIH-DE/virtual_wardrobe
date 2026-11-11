import '../data/points.dart';
import 'generated/app_localizations.dart';

extension PointsActionLocalization on PointsAction {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    PointsAction.tryOn => l10n.pointsActionTryOn,
    PointsAction.garmentAnalysis => l10n.pointsActionGarmentAnalysis,
    PointsAction.flatLay => l10n.pointsActionFlatLay,
    PointsAction.baseModel => l10n.pointsActionBaseModel,
    PointsAction.closetAnalysis => l10n.pointsActionClosetAnalysis,
    PointsAction.outfitAdvice => l10n.pointsActionOutfitAdvice,
    PointsAction.matchLookReference => l10n.pointsActionMatchLookReference,
    PointsAction.matchLookMatch => l10n.pointsActionMatchLookMatch,
    PointsAction.tripOutfits => l10n.pointsActionTripOutfits,
    PointsAction.tripPacking => l10n.pointsActionTripPacking,
  };
}

extension PointsTransactionLocalization on PointsTransaction {
  /// Unknown kinds and actions (added after this build) get generic copy.
  String localizedTitle(AppLocalizations l10n) {
    final actionLabel = action?.localizedLabel(l10n) ?? l10n.pointsActionOther;
    return switch (kind) {
      PointsTransactionKind.dailyGrant => l10n.pointsKindDailyGrant,
      PointsTransactionKind.charge => actionLabel,
      PointsTransactionKind.refund => l10n.pointsKindRefund(actionLabel),
      PointsTransactionKind.adjust => l10n.pointsKindAdjust,
      PointsTransactionKind.unknown =>
        action == null ? l10n.pointsKindOther : actionLabel,
    };
  }
}
