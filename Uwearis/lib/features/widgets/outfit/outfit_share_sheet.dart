import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../common/overlays/share_image_sheet.dart';
import 'outfit_share_card.dart';

/// Shares an outfit as an [OutfitShareCard] image. [style]/[seasons] arrive
/// already display-formatted.
Future<void> showOutfitShareSheet(
  BuildContext context, {
  required String imageUrl,
  required String name,
  required List<String> style,
  required List<String> seasons,
  required List<String> garmentImageUrls,
}) {
  final l10n = AppLocalizations.of(context);

  // Index 0 is the outfit render; 1.. are the garment thumbnails.
  final urls = [imageUrl, ...garmentImageUrls];

  return showShareImageSheet(
    context,
    title: l10n.shareThisOutfit,
    precacheUrls: urls,
    cardBuilder: (images) => OutfitShareCard(
      image: images.first,
      garmentImages: images.skip(1).toList(),
      name: name,
      styles: style,
      seasons: seasons,
    ),
    text: name,
  );
}
