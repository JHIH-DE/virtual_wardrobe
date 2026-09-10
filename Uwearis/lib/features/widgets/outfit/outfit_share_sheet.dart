import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../common/overlays/share_image_sheet.dart';
import 'outfit_share_card.dart';

/// Opens the share sheet for an outfit — a large photo, the name, a compact
/// style / season line and a row of garment thumbnails, rendered as an
/// [OutfitShareCard] and handed to [showShareImageSheet].
///
/// [style]/[seasons] are already display-formatted by the caller (Outfit
/// Details owns the snake_case → Title Case rule). [garmentImageUrls] are the
/// outfit's garment photos, in order.
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
