import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/editorial_typography.dart';
import '../common/buttons/accent_pill_button.dart';
import '../common/cards/card_corner_badge.dart';
import 'editorial_text.dart';

/// How a [MagazineItemCard] sits on its page.
enum MagazineItemCardVariant {
  /// A raised white card with rounded corners (articles, Explore's home).
  card,

  /// Flat and square, the text flush with the photo, on a 4:5 photo: a story
  /// slide's product selection, where card chrome would read as a shop UI.
  editorial,
}

/// A product shown in the magazine: photo on the studio backdrop, name, a
/// secondary line, and optionally a save heart and a shop action.
class MagazineItemCard extends StatelessWidget {
  static const double textInset = 12;

  /// CJK wraps between any characters, so only Latin words can break.
  static final RegExp _latinWord = RegExp(r"[A-Za-z0-9À-ɏ'’,.]+");

  final Widget photo;
  final String name;
  final String? detail;
  final String? saveLabel;
  final VoidCallback? onSave;
  final String? shopLabel;
  final VoidCallback? onShop;
  final MagazineItemCardVariant variant;

  const MagazineItemCard({
    super.key,
    required this.photo,
    required this.name,
    this.detail,
    this.saveLabel,
    this.onSave,
    this.shopLabel,
    this.onShop,
    this.variant = MagazineItemCardVariant.card,
  });

  bool get _editorial => variant == MagazineItemCardVariant.editorial;

  /// The text's horizontal inset inside the card.
  double get _textInset => _editorial ? 0 : textInset;

  EditorialTextStyle get _nameStyle => _editorial
      ? EditorialTypography.productName
      : EditorialTextStyle(AppTextStyle.editorialCardTitle);

  EditorialTextStyle get _detailStyle => _editorial
      ? EditorialTypography.productMeta
      : EditorialTextStyle(
          AppTextStyle.regular13.copyWith(color: AppColors.textSecondary),
        );

  /// Whether [cards] can sit two to a row at [rowWidth] without splitting a
  /// word of a name or of the line under it; otherwise the caller stacks
  /// them.
  static bool fitsTwoPerRow(
    BuildContext context,
    Iterable<MagazineItemCard> cards,
    double rowWidth,
  ) {
    final halfWidth = (rowWidth - AppDimens.cardSpacing) / 2;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var fits = true;
    void measure(String? text, TextStyle style, double inset) {
      for (final word in _latinWord.allMatches(text ?? '')) {
        final painter = TextPainter(
          text: TextSpan(text: word[0], style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        fits = fits && painter.width <= halfWidth - inset * 2;
        painter.dispose();
      }
    }

    for (final card in cards) {
      measure(card.name, card._nameStyle.style, card._textInset);
      measure(card.detail, card._detailStyle.style, card._textInset);
    }
    return fits;
  }

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final shopLabel = this.shopLabel;
    return Container(
      clipBehavior: _editorial ? Clip.none : Clip.antiAlias,
      decoration: _editorial
          ? null
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowResting, blurRadius: 12),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _editorial ? 4 / 5 : 457 / 370,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MagazineProductPhoto(photo: photo),
                if (onSave != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: saveLabel,
                      child: CardCornerBadge(
                        icon: Icons.favorite_border,
                        backgroundColor: AppColors.surfaceTranslucent,
                        iconColor: AppColors.hintText,
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: const [],
                        size: 36,
                        iconSize: 20,
                        onTap: onSave,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _textInset,
              vertical: textInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorialText(name, style: _nameStyle),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  EditorialText(detail, style: _detailStyle),
                ],
                if (shopLabel != null && onShop != null) ...[
                  const SizedBox(height: 10),
                  AccentPillButton(
                    label: shopLabel,
                    onPressed: onShop,
                    variant: AccentPillButtonVariant.editorial,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A product cut-out on the studio backdrop, as on [MagazineItemCard]; also
/// an Outfit Breakdown's pieces.
class MagazineProductPhoto extends StatelessWidget {
  final Widget photo;

  const MagazineProductPhoto({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    // The multiply filter tints transparent pixels too, so it is clipped to
    // this box.
    return ClipRect(
      child: ColoredBox(
        color: AppColors.productPhotoBackdrop,
        child: Padding(
          padding: const EdgeInsets.all(8),
          // Multiply turns the photos' white studio background into the
          // backdrop colour.
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              AppColors.productPhotoBackdrop,
              BlendMode.multiply,
            ),
            child: photo,
          ),
        ),
      ),
    );
  }
}
