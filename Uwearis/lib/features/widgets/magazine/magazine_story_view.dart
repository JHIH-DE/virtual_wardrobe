import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/magazine.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/labeled_divider.dart';
import 'magazine_credits.dart';
import 'magazine_item_card.dart';
import 'magazine_item_grid.dart';
import 'magazine_network_photo.dart';

/// One story's cover, headline and body blocks, unscrolled: the App's story
/// page and the CMS preview each put it in their own scroll view.
class MagazineStoryView extends StatelessWidget {
  static const double coverAspectRatio = 4 / 5;
  static const double _bodyImagePlaceholderRatio = 4 / 3;

  final MagazineStory story;

  /// Shown on items with an available product; null hides the action.
  final void Function(MagazineItem item)? onShopItem;

  /// Opens a credited source; null lists the sources without links.
  final void Function(String url)? onOpenSource;

  const MagazineStoryView({
    super.key,
    required this.story,
    this.onShopItem,
    this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final summary = story.summary;
    final title = summary.title;
    final subtitle = summary.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.editorialPhotoRadius),
          child: AspectRatio(
            aspectRatio: coverAspectRatio,
            child: MagazineNetworkPhoto(photo: summary.cover),
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
        if (summary.isSponsored) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MagazineSponsorLabel(story: summary),
          ),
          const SizedBox(height: 12),
        ],
        if (title != null) Text(title, style: AppTextStyle.editorialHeadline),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyle.editorialSubtitle),
        ],
        for (final block in story.blocks) ...[
          const SizedBox(height: AppDimens.titleGap),
          _buildBlock(context, block),
        ],
        if (story.hasCredits) ...[
          const SizedBox(height: AppDimens.titleGap),
          MagazineCreditsSection(story: story, onOpenSource: onOpenSource),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, MagazineBlock block) =>
      switch (block) {
        MagazineHeadingBlock(:final text) => Text(
          text,
          style: AppTextStyle.editorialSectionTitle,
        ),
        MagazineParagraphBlock(:final text) => Text(
          text,
          style: AppTextStyle.regular16.copyWith(
            height: 1.6,
            color: AppColors.textPrimary,
          ),
        ),
        MagazineImageBlock(:final photo, :final caption) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                AppDimens.editorialPhotoRadius,
              ),
              child: MagazineNetworkPhoto(
                photo: photo,
                fit: BoxFit.fitWidth,
                placeholderAspectRatio: _bodyImagePlaceholderRatio,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 8),
              Text(
                caption,
                style: AppTextStyle.regular13.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        MagazineItemBlock(:final item) => MagazineItemGrid(
          cards: [itemCard(context, item, onShop: onShopItem)],
        ),
        MagazineItemGroupBlock(:final title, :final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              LabeledDivider(label: title),
              const SizedBox(height: AppDimens.cardSpacing),
            ],
            MagazineItemGrid(
              cards: [
                for (final item in items)
                  itemCard(context, item, onShop: onShopItem),
              ],
            ),
          ],
        ),
      };

  /// [item]'s card; the shop action shows only while it's buyable and
  /// [onShop] is set. Shared with the story slides' products page.
  static MagazineItemCard itemCard(
    BuildContext context,
    MagazineItem item, {
    void Function(MagazineItem item)? onShop,
    MagazineItemCardVariant variant = MagazineItemCardVariant.card,
  }) {
    return MagazineItemCard(
      variant: variant,
      photo: MagazineNetworkPhoto(photo: item.photo, fit: BoxFit.contain),
      name: item.name ?? '',
      detail: itemDetail(context, item),
      shopLabel: AppLocalizations.of(context).magazineShop,
      onShop: onShop != null && item.isShoppable ? () => onShop(item) : null,
    );
  }

  /// "Brand · NT$590": the brand, plus the price while the product is on sale.
  static String? itemDetail(BuildContext context, MagazineItem item) {
    final product = item.product;
    final brand = item.brand ?? product?.brand;
    final price = product != null && product.isAvailable ? product.price : null;
    final parts = [
      if (brand != null && brand.isNotEmpty) brand,
      if (price != null)
        NumberFormat.simpleCurrency(
          locale: Localizations.localeOf(context).toLanguageTag(),
          name: product!.currency,
          decimalDigits: 0,
        ).format(price),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
