import 'package:flutter/widgets.dart';

import '../../../data/garment.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/overlays/share_image_sheet.dart';
import 'garment_share_card.dart';

/// Opens the share sheet for [garment] — assembles the card's category /
/// detail / match lines and renders a [GarmentShareCard].
Future<void> showGarmentShareSheet(
  BuildContext context, {
  required Garment garment,
  int? versatilityScore,
}) {
  final l10n = AppLocalizations.of(context);
  final sub = garment.subCategory.trim();
  final color = garment.color?.trim() ?? '';
  final brand = garment.brand?.trim() ?? '';
  final price = garment.price;
  final date = garment.purchaseDate;
  final score = versatilityScore;

  final categoryLine = [
    garment.category.localizedLabel(context),
    if (sub.isNotEmpty) sub,
    if (color.isNotEmpty) color,
  ].join('   ·   ');

  final detailLine = [
    if (brand.isNotEmpty) brand,
    if (price != null) '\$${price.toStringAsFixed(0)}',
    if (date != null) '${date.year}/${date.month}/${date.day}',
  ].join('   ·   ');

  final matchLine = score == null
      ? null
      : '${l10n.closetMatchLabel}  $score%   ·   '
            '${versatilityScoreTier(l10n, score)}';

  final name = garment.name.trim().isEmpty
      ? garment.category.localizedLabel(context)
      : garment.name.trim();

  return showShareImageSheet(
    context,
    title: l10n.shareThisPiece,
    precacheUrls: [garment.imageUrl ?? ''],
    cardBuilder: (images) => GarmentShareCard(
      image: images.first,
      name: name,
      categoryLine: categoryLine,
      detailLine: detailLine,
      matchLine: matchLine,
    ),
    text: garment.name.trim().isEmpty ? null : garment.name.trim(),
  );
}
