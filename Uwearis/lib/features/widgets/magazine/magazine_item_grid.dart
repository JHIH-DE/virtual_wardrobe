import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import 'magazine_item_card.dart';

/// [cards] two to a row with matching heights; stacked one per row once a
/// word of a name or its detail line wouldn't fit half the width.
class MagazineItemGrid extends StatelessWidget {
  final List<MagazineItemCard> cards;

  const MagazineItemGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paired =
            cards.length > 1 &&
            MagazineItemCard.fitsTwoPerRow(
              context,
              cards,
              constraints.maxWidth,
            );
        if (!paired) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppDimens.cardSpacing),
                cards[i],
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i += 2) ...[
              if (i > 0) const SizedBox(height: AppDimens.cardSpacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[i]),
                    const SizedBox(width: AppDimens.cardSpacing),
                    Expanded(
                      child: i + 1 < cards.length
                          ? cards[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
