import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/editorial_typography.dart';
import '../../../data/magazine.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/adaptive_side_layout.dart';
import '../common/app_divider.dart';
import '../common/buttons/accent_pill_button.dart';
import 'editorial_text.dart';
import 'magazine_credits.dart';
import 'magazine_item_card.dart';
import 'magazine_item_grid.dart';
import 'magazine_network_photo.dart';
import 'magazine_story_view.dart';

/// The slides' shared measures (their type is [EditorialTypography]). Each
/// photo has the ratio its
/// layout prefers (the shape its photos are shot or picked at), so the
/// composition stays whole; only on a short screen or with large text may it
/// crop a little, down to a set limit, before the slide scrolls instead. A
/// photo never grows past its preferred ratio to fill the screen, and is
/// never stretched.
abstract final class _Slide {
  static const double inset = 24;
  static const double labelGap = 8;
  static const double blockGap = 16;
  static const double captionGap = 8;
  static const double columnGap = 12;
  static const double maxOverlayCopyShare = 0.5;

  /// Between a last page's content and the story's credits.
  static const double footerGap = 40;

  /// How far the overlay copy's gradient reaches beyond the copy.
  static const double overlayFade = 96;

  /// A dark text page: the darkest warm tone the theme has.
  static const Color darkPage = AppColors.textPrimary;

  /// The short rule under a gallery title, and the space on either side.
  static const double galleryRuleWidth = 16;
  static const double galleryRuleGap = 10;

  /// Inset of a caption laid over its photo.
  static const double overlayCaptionInset = 16;

  /// "THE DETAILS / 03"; null without a label.
  static String? sectionLabel(String? label, int? pageNumber) {
    if (label == null) return null;
    final upper = label.toUpperCase();
    return pageNumber == null
        ? upper
        : '$upper / ${pageNumber.toString().padLeft(2, '0')}';
  }
}

/// A photo's height at [width]: its preferred ratio [preferred] (height /
/// width), lowered toward [minRatio] (a gentle crop) only when [space] is
/// short of it.
double _fit(double width, double space, double minRatio, double preferred) =>
    space.clamp(width * minRatio, width * preferred);

/// Whether every Latin word of [images]' captions fits a column [width]
/// wide at the current text size, set as [mode] sets them.
bool _captionsFit(
  BuildContext context,
  Iterable<MagazineCaptionedPhoto> images,
  double width, {
  _CaptionMode mode = _CaptionMode.plain,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  if (mode == _CaptionMode.overlay) width -= _Slide.overlayCaptionInset * 2;
  for (final image in images) {
    for (final (text, style) in [
      (image.title, EditorialTypography.itemTitle),
      (image.caption, EditorialTypography.caption),
    ]) {
      if (text != null &&
          longestLatinWordWidth(text, style.style, scaler) > width) {
        return false;
      }
    }
  }
  return true;
}

/// Heights of the copy around the photos, so a layout knows the space left
/// for them.
class _Measure {
  final EditorialTextMeasure _text;

  _Measure(BuildContext context) : _text = EditorialTextMeasure(context);

  double text(String? text, EditorialTextStyle style, double width) =>
      _text.height(text, style, width);

  double header(String? label, String? heading, double width, {String? info}) {
    if (label == null && heading == null && info == null) return 0;
    return (label == null
            ? 0
            : text(label, EditorialTypography.sectionLabel, width) +
                  _Slide.labelGap) +
        text(heading, EditorialTypography.pageHeading, width) +
        (info == null
            ? 0
            : _Slide.labelGap +
                  text(info, EditorialTypography.productMeta, width)) +
        _Slide.blockGap;
  }

  double body(String? body, double width) => body == null
      ? 0
      : _Slide.blockGap + text(body, EditorialTypography.body, width);

  /// A photo's title and caption as [_PhotoCaption] sets them.
  double photoCaption(
    MagazineCaptionedPhoto image,
    double width, {
    required bool ruled,
  }) {
    final title = image.title;
    final caption = image.caption;
    final gap = ruled ? _Slide.galleryRuleGap * 2 + 1 : _PhotoCaption.plainGap;
    return text(title, EditorialTypography.itemTitle, width) +
        (title != null && caption != null
            ? gap
            : title != null && ruled
            ? _Slide.galleryRuleGap + 1
            : 0) +
        text(caption, EditorialTypography.caption, width);
  }

  /// How tall a photo [width] wide must be for [images]' captions laid
  /// over it to cover at most [_overlayShare] of it.
  double overlayPhoto(Iterable<MagazineCaptionedPhoto> images, double width) {
    final inner = width - _Slide.overlayCaptionInset * 2;
    var tallest = 0.0;
    for (final image in images) {
      if (!image.hasText) continue;
      tallest = math.max(tallest, photoCaption(image, inner, ruled: true));
    }
    return tallest == 0
        ? 0
        : (tallest + _Slide.overlayCaptionInset * 2) / _overlayShare;
  }

  static const double _overlayShare = 0.6;

  /// The tallest caption of [images] at [width], with its gap above; none
  /// for captions laid over their photos.
  double captions(
    Iterable<MagazineCaptionedPhoto> images,
    double width, {
    _CaptionMode mode = _CaptionMode.plain,
  }) {
    if (mode == _CaptionMode.overlay) return 0;
    var tallest = 0.0;
    for (final image in images) {
      if (!image.hasText) continue;
      tallest = math.max(
        tallest,
        _Slide.captionGap +
            photoCaption(image, width, ruled: mode == _CaptionMode.editorial),
      );
    }
    return tallest;
  }
}

/// A story's cover: the first slide, drawn from the story itself (cover,
/// kicker, title, subtitle) the way an Immersive slide is, its title in
/// display type. [padding] keeps the copy clear of the reader's chrome and
/// the system insets.
class MagazineCoverSlideView extends StatelessWidget {
  final MagazineStorySummary summary;
  final EdgeInsets padding;

  /// Shown after the kicker ("STYLE GUIDE / 01"); null shows the kicker
  /// alone.
  final int? pageNumber;

  const MagazineCoverSlideView({
    super.key,
    required this.summary,
    this.padding = EdgeInsets.zero,
    this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    final title = summary.title;
    return _OverlayCopyLayout(
      photo: summary.cover,
      padding: padding,
      textPosition: MagazineSlideTextPosition.bottom,
      copy: _OverlayCopy(
        disclosure: summary.isSponsored
            ? MagazineSponsorLabel(story: summary, onPhoto: true)
            : null,
        label: _Slide.sectionLabel(summary.kicker, pageNumber),
        title: title,
        body: summary.subtitle,
      ),
    );
  }
}

/// One slide after a story's cover, laid out by its type. Renders data only:
/// the reader owns paging, chrome and navigation. [padding] is the area the
/// reader's chrome and the system insets cover; an Immersive photo may run
/// under it, nothing else does.
class MagazineSlideView extends StatelessWidget {
  final MagazineSlide slide;
  final EdgeInsets padding;

  /// The slide's position in its story, shown after its label.
  final int? pageNumber;

  /// The story's cover, shown beside a selection's wardrobe prompt.
  final MagazinePhoto? storyCover;

  /// Shown on items with an available product; null hides the action.
  final void Function(MagazineItem item)? onShopItem;

  /// Match Your Wardrobe with the look it's offered on (a Breakdown's look,
  /// the cover beside the wardrobe prompt); null hides the button (the
  /// prompt's copy still shows).
  final void Function(MagazinePhoto look)? onMatchWardrobe;

  /// Shown under the slide's content, a scroll away (the story's credits on
  /// its last page).
  final Widget? footer;

  const MagazineSlideView({
    super.key,
    required this.slide,
    this.padding = EdgeInsets.zero,
    this.pageNumber,
    this.storyCover,
    this.onShopItem,
    this.onMatchWardrobe,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final slide = this.slide;
    final label = _Slide.sectionLabel(slide.label, pageNumber);
    final measure = _Measure(context);
    final layout = _layout(context, slide, label, measure);
    final footer = this.footer;
    if (footer == null || layout is _FlowLayout) return layout;
    return _FooterBelow(padding: padding, footer: footer, child: layout);
  }

  Widget _layout(
    BuildContext context,
    MagazineSlide slide,
    String? label,
    _Measure measure,
  ) {
    return switch (slide) {
      MagazineImmersiveSlide(:final photo, :final textPosition) =>
        _OverlayCopyLayout(
          photo: photo,
          padding: padding,
          textPosition: textPosition,
          copy: _OverlayCopy(
            label: label,
            title: slide.heading,
            body: slide.body,
          ),
        ),
      MagazineFeatureSlide() => _FlowLayout(
        padding: padding,
        footer: footer,
        builder: (width, height) =>
            _feature(slide, label, measure, width, height),
      ),
      MagazineDetailSlide() => _FlowLayout(
        padding: padding,
        footer: footer,
        builder: (width, height) =>
            _detail(slide, label, measure, width, height),
      ),
      MagazineGallerySlide(:final images, :final numbered, :final imageRatio) =>
        _FlowLayout(
          padding: padding,
          footer: footer,
          builder: (width, height) => [
            ..._header(label, slide.heading),
            _Gallery(
              images: numbered ? _numbered(images) : images,
              space:
                  height -
                  measure.header(label, slide.heading, width) -
                  measure.body(slide.body, width),
              shape: imageRatio == MagazineImageRatio.square
                  ? _GalleryShape.square
                  : _GalleryShape.portrait,
              captions: imageRatio == MagazineImageRatio.square
                  ? _CaptionMode.editorial
                  : _CaptionMode.overlay,
            ),
            ..._body(slide.body),
          ],
        ),
      MagazineListSlide(:final entries, :final numbered) => _FlowLayout(
        padding: padding,
        footer: footer,
        builder: (width, height) {
          final paired = entries.length == 2;
          final thumbWidth = width * (paired ? 0.55 : 0.42);
          final rules =
              (_IllustratedList.dividerSpacing * 2 + 1) * (entries.length - 1);
          final thumbHeight = _fit(
            thumbWidth,
            (height -
                    measure.header(label, slide.heading, width) -
                    measure.body(slide.body, width) -
                    rules) /
                entries.length,
            paired ? 4 / 3 : 1,
            paired ? 3 / 2 : 5 / 4,
          );
          return [
            ..._header(label, slide.heading),
            _IllustratedList(
              entries: entries,
              numbered: numbered || paired,
              alternating: paired,
              divided: true,
              thumbWidth: thumbWidth,
              thumbHeight: thumbHeight,
            ),
            ..._body(slide.body),
          ];
        },
      ),
      MagazineBreakdownSlide(:final look, :final pieces) => _FlowLayout(
        padding: padding,
        footer: footer,
        builder: (width, height) {
          final onMatch = onMatchWardrobe;
          final button = look != null && onMatch != null;
          return [
            ..._header(label, slide.heading),
            _Breakdown(
              look: look,
              pieces: pieces,
              space:
                  height -
                  measure.header(label, slide.heading, width) -
                  measure.body(slide.body, width) -
                  (button ? 64 : 0),
            ),
            ..._body(slide.body),
            if (button) ...[
              const SizedBox(height: _Slide.blockGap),
              _MatchWardrobeButton(onPressed: () => onMatch(look)),
            ],
          ];
        },
      ),
      MagazineTypographySlide() => _TypographyLayout(
        slide: slide,
        label: label,
        padding: padding,
      ),
      MagazineSelectionSlide(:final items, :final wardrobePrompt) =>
        _FlowLayout(
          padding: padding,
          footer: footer,
          builder: (width, height) => [
            ..._header(label, slide.heading),
            if (slide.body case final body?) ...[
              EditorialText(body, style: EditorialTypography.body),
              const SizedBox(height: _Slide.blockGap),
            ],
            MagazineItemGrid(
              cards: [
                for (final item in items)
                  MagazineStoryView.itemCard(
                    context,
                    item,
                    onShop: onShopItem,
                    variant: MagazineItemCardVariant.editorial,
                  ),
              ],
            ),
            if (wardrobePrompt) ...[
              const AppDivider(spacing: _Slide.blockGap),
              _WardrobePrompt(
                cover: storyCover,
                width: width,
                onMatchWardrobe: onMatchWardrobe,
              ),
            ],
          ],
        ),
    };
  }

  /// The copy as its own block above the photo (default) or below it.
  static List<Widget> _feature(
    MagazineFeatureSlide slide,
    String? label,
    _Measure measure,
    double width,
    double height,
  ) {
    final caption = slide.caption;
    final space =
        height -
        measure.header(label, slide.heading, width, info: slide.info) -
        measure.body(slide.body, width) -
        (caption == null
            ? 0
            : _Slide.captionGap +
                  measure.text(caption, EditorialTypography.caption, width));
    final (minRatio, maxRatio) = switch (slide.imageRatio) {
      MagazineImageRatio.portrait => (5 / 4, 3 / 2),
      MagazineImageRatio.square => (1.0, 1.0),
      MagazineImageRatio.landscape => (3 / 5, 2 / 3),
    };
    final photo = [
      _photo(slide.photo, width, _fit(width, space, minRatio, maxRatio)),
      if (caption != null) ...[
        const SizedBox(height: _Slide.captionGap),
        EditorialText(caption, style: EditorialTypography.caption),
      ],
    ];
    final header = _header(label, slide.heading, info: slide.info);
    if (slide.textPosition == MagazineSlideTextPosition.bottom) {
      return [
        ...photo,
        const SizedBox(height: _Slide.blockGap),
        ...header,
        if (slide.body case final body?)
          EditorialText(body, style: EditorialTypography.body),
      ];
    }
    return [...header, ...photo, ..._body(slide.body)];
  }

  /// Main photo, swatches and close-ups, whichever the page has; without a
  /// main photo the close-ups take its place as a gallery.
  static List<Widget> _detail(
    MagazineDetailSlide slide,
    String? label,
    _Measure measure,
    double width,
    double height,
  ) {
    final main = slide.main;
    final details = slide.details;
    final swatches = slide.swatches;
    final hasPhotos = main != null || details.isNotEmpty;
    final swatchRow = swatches.isEmpty
        ? null
        : _SwatchRow(swatches, height: hasPhotos ? 48 : 120);
    final swatchSpace = swatchRow == null
        ? 0.0
        : swatchRow.height +
              _Slide.columnGap +
              (swatches.any((s) => s.name != null)
                  ? _Slide.captionGap +
                        measure.text('Aa', EditorialTypography.caption, width)
                  : 0);
    var space =
        height -
        measure.header(label, slide.heading, width) -
        measure.body(slide.body, width) -
        swatchSpace;
    final children = <Widget>[..._header(label, slide.heading)];
    if (main == null) {
      if (swatchRow != null) {
        children.addAll([swatchRow, const SizedBox(height: _Slide.columnGap)]);
      }
      if (details.length == 1) {
        children.add(
          _CaptionedPhoto(
            image: details.single,
            height: _fit(
              width,
              space - measure.captions(details, width),
              1,
              5 / 4,
            ),
          ),
        );
      } else if (details.isNotEmpty) {
        children.add(
          _Gallery(images: details, space: space, shape: _GalleryShape.square),
        );
      }
    } else {
      final columnWidth = details.isEmpty
          ? width
          : (width - _Slide.columnGap * (details.length - 1)) / details.length;
      final (detailMin, detailMax) = switch (details.length) {
        1 => (3 / 5, 2 / 3),
        2 => (1.0, 5 / 4),
        _ => (1.0, 1.0),
      };
      final detailCaptions = measure.captions(details, columnWidth);
      final detailSpace = details.isEmpty
          ? 0
          : _Slide.columnGap + detailCaptions + columnWidth * detailMin;
      final mainCaption = measure.captions([main], width);
      final mainHeight = _fit(
        width,
        space - detailSpace - mainCaption,
        2 / 3,
        3 / 4,
      );
      space -= mainHeight + mainCaption;
      children.add(_CaptionedPhoto(image: main, height: mainHeight));
      if (swatchRow != null) {
        children.addAll([const SizedBox(height: _Slide.columnGap), swatchRow]);
      }
      if (details.isNotEmpty) {
        children.addAll([
          const SizedBox(height: _Slide.columnGap),
          _PhotoRow(
            images: details,
            photoHeight: _fit(
              columnWidth,
              space - _Slide.columnGap - detailCaptions,
              detailMin,
              detailMax,
            ),
          ),
        ]);
      }
    }
    return [...children, ..._body(slide.body)];
  }

  /// [images] with "1. " before their titles; an untitled one gets its
  /// number alone.
  static List<MagazineCaptionedPhoto> _numbered(
    List<MagazineCaptionedPhoto> images,
  ) => [
    for (final (i, image) in images.indexed)
      MagazineCaptionedPhoto(
        photo: image.photo,
        title: image.title == null ? '${i + 1}' : '${i + 1}. ${image.title}',
        caption: image.caption,
      ),
  ];

  /// Label, heading and the optional [info] line, then the gap to what
  /// follows.
  static List<Widget> _header(String? label, String? heading, {String? info}) {
    if (label == null && heading == null && info == null) return const [];
    return [
      if (label != null) ...[
        EditorialText(label, style: EditorialTypography.sectionLabel),
        const SizedBox(height: _Slide.labelGap),
      ],
      if (heading != null)
        EditorialText(heading, style: EditorialTypography.pageHeading),
      if (info != null) ...[
        const SizedBox(height: _Slide.labelGap),
        EditorialText(info, style: EditorialTypography.productMeta),
      ],
      const SizedBox(height: _Slide.blockGap),
    ];
  }

  static List<Widget> _body(String? body) => [
    if (body != null) ...[
      const SizedBox(height: _Slide.blockGap),
      EditorialText(body, style: EditorialTypography.body),
    ],
  ];
}

/// A square-cornered editorial photo.
Widget _photo(MagazinePhoto? photo, double width, double height) => SizedBox(
  width: width,
  height: height,
  child: MagazineNetworkPhoto(photo: photo),
);

/// A product cut-out, shown whole on the studio backdrop.
Widget _productPhoto(MagazinePhoto? photo, double width, double height) =>
    SizedBox(
      width: width,
      height: height,
      child: MagazineProductPhoto(
        photo: MagazineNetworkPhoto(photo: photo, fit: BoxFit.contain),
      ),
    );

/// A slide on the page background whose blocks flow down from under the
/// chrome. [builder] gets the content width and the screen height left for
/// content, to size photos by.
class _FlowLayout extends StatelessWidget {
  final EdgeInsets padding;
  final List<Widget> Function(double width, double height) builder;

  /// After the blocks, past the screen's foot.
  final Widget? footer;

  const _FlowLayout({
    required this.padding,
    required this.builder,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final scrollPadding = EdgeInsets.fromLTRB(
      _Slide.inset + padding.left,
      padding.top + 8,
      _Slide.inset + padding.right,
      padding.bottom + _Slide.inset,
    );
    return ColoredBox(
      color: AppColors.pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: scrollPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...builder(
                constraints.maxWidth - scrollPadding.horizontal,
                math.max(0, constraints.maxHeight - scrollPadding.vertical),
              ),
              if (footer case final footer?) ...[
                const SizedBox(height: _Slide.footerGap),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-screen slide (Immersive, Typography) with [footer] on the page
/// colour below it, a scroll away.
class _FooterBelow extends StatelessWidget {
  final EdgeInsets padding;
  final Widget footer;
  final Widget child;

  const _FooterBelow({
    required this.padding,
    required this.footer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: constraints.maxHeight, child: child),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _Slide.inset + padding.left,
                  _Slide.footerGap,
                  _Slide.inset + padding.right,
                  padding.bottom + _Slide.inset,
                ),
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a photo's title and caption go; the type is the same in each.
/// [plain]: under the photo (a detail). [overlay]: over the foot of the
/// photo on a scrim, a short rule between title and caption (a gallery of
/// people). [editorial]: the same, under the photo (products and details).
enum _CaptionMode { plain, overlay, editorial }

/// A photo with its caption set in [mode].
class _CaptionedPhoto extends StatelessWidget {
  final MagazineCaptionedPhoto image;
  final double height;
  final _CaptionMode mode;

  const _CaptionedPhoto({
    required this.image,
    required this.height,
    this.mode = _CaptionMode.plain,
  });

  @override
  Widget build(BuildContext context) {
    final photo = _photo(image.photo, double.infinity, height);
    if (!image.hasText) return photo;
    if (mode == _CaptionMode.overlay) {
      return SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.overlayMedium.withValues(alpha: 0),
                    AppColors.overlayMedium,
                  ],
                  stops: const [0.55, 1],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(_Slide.overlayCaptionInset),
                child: _PhotoCaption(
                  image,
                  ruled: true,
                  surface: EditorialSurface.image,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        photo,
        const SizedBox(height: _Slide.captionGap),
        _PhotoCaption(image, ruled: mode == _CaptionMode.editorial),
      ],
    );
  }
}

/// A photo's title over its caption; [ruled] puts a short rule between.
class _PhotoCaption extends StatelessWidget {
  static const double plainGap = 2;

  final MagazineCaptionedPhoto image;
  final bool ruled;
  final EditorialSurface surface;

  const _PhotoCaption(
    this.image, {
    this.ruled = false,
    this.surface = EditorialSurface.page,
  });

  @override
  Widget build(BuildContext context) {
    final title = image.title;
    final caption = image.caption;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          EditorialText(
            title,
            style: EditorialTypography.itemTitle.on(surface),
          ),
        if (title != null && ruled) ...[
          const SizedBox(height: _Slide.galleryRuleGap),
          Container(
            width: _Slide.galleryRuleWidth,
            height: 1,
            color: surface == EditorialSurface.image
                ? AppColors.onPhotoMuted
                : AppColors.textSecondary,
          ),
          if (caption != null) const SizedBox(height: _Slide.galleryRuleGap),
        ] else if (title != null && caption != null)
          const SizedBox(height: plainGap),
        if (caption != null)
          EditorialText(
            caption,
            style: EditorialTypography.caption.on(surface),
          ),
      ],
    );
  }
}

/// Captioned photos side by side at one height, so they compare; one per
/// row, beside its caption, when a caption's word wouldn't fit its column.
class _PhotoRow extends StatelessWidget {
  final List<MagazineCaptionedPhoto> images;
  final double photoHeight;
  final _CaptionMode mode;

  const _PhotoRow({
    required this.images,
    required this.photoHeight,
    this.mode = _CaptionMode.plain,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columnWidth =
            (width - _Slide.columnGap * (images.length - 1)) / images.length;
        if (!_captionsFit(context, images, columnWidth, mode: mode)) {
          return _IllustratedList(
            entries: images,
            thumbWidth: width * 0.34,
            thumbHeight: width * 0.34 * 5 / 4,
          );
        }
        return _row();
      },
    );
  }

  Widget _row() {
    final hasText = images.any((i) => i.hasText);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, image) in images.indexed) ...[
          if (i > 0) const SizedBox(width: _Slide.columnGap),
          Expanded(
            child: mode == _CaptionMode.plain
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _photo(image.photo, double.infinity, photoHeight),
                      if (hasText) ...[
                        const SizedBox(height: _Slide.captionGap),
                        _PhotoCaption(image),
                      ],
                    ],
                  )
                : _CaptionedPhoto(
                    image: image,
                    height: photoHeight,
                    mode: mode,
                  ),
          ),
        ],
      ],
    );
  }
}

/// A gallery's photo shape as height / width: people at 2:3 (cropping to
/// no wider than 3:4 when space is short), products and details at 1:1.
/// A Gallery slide's photos grow past that to fill the screen, up to
/// [fillMax], trimming only their sides.
enum _GalleryShape {
  portrait(4 / 3, 3 / 2, 7 / 2),
  square(1, 1, 3 / 2);

  final double min;
  final double preferred;
  final double fillMax;
  const _GalleryShape(this.min, this.preferred, this.fillMax);
}

/// Two side by side, three as one lead photo over two, four two by two.
/// With [captions] other than plain (a Gallery slide) the photos fill
/// [space]; a detail page's stay at their preferred shape. Falls back to an
/// illustrated list when a caption's word wouldn't fit its column at the
/// current text size.
class _Gallery extends StatelessWidget {
  /// A Gallery slide's lead photo takes about this share of the height its
  /// photos fill.
  static const double _leadShare = 0.48;

  final List<MagazineCaptionedPhoto> images;

  /// The height the gallery should come close to filling.
  final double space;
  final _GalleryShape shape;
  final _CaptionMode captions;

  const _Gallery({
    required this.images,
    required this.space,
    required this.shape,
    this.captions = _CaptionMode.plain,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columnWidth = (width - _Slide.columnGap) / 2;
        if (!_captionsFit(context, images, columnWidth, mode: captions)) {
          return _IllustratedList(
            entries: images,
            thumbWidth: width * 0.34,
            thumbHeight: width * 0.34 * 5 / 4,
          );
        }
        final measure = _Measure(context);
        final fill = captions != _CaptionMode.plain;
        final tallest = fill ? shape.fillMax : shape.preferred;
        double below(List<MagazineCaptionedPhoto> row, double columnWidth) =>
            measure.captions(row, columnWidth, mode: captions);
        // Captions laid over a photo never cover most of it.
        double shortest(List<MagazineCaptionedPhoto> row, double width) =>
            captions == _CaptionMode.overlay
            ? measure.overlayPhoto(row, width)
            : 0;
        double rowHeight(List<MagazineCaptionedPhoto> row, double rowSpace) =>
            math.max(
              _fit(
                columnWidth,
                rowSpace - below(row, columnWidth),
                shape.min,
                tallest,
              ),
              shortest(row, columnWidth),
            );

        if (images.length == 2) {
          return _PhotoRow(
            images: images,
            photoHeight: rowHeight(images, space),
            mode: captions,
          );
        }
        if (images.length == 3) {
          final lead = images.first;
          final rest = images.sublist(1);
          final leadCaption = below([lead], width);
          final restCaption = below(rest, columnWidth);
          final leadHeight = fill
              ? math.max(
                  _fit(
                    width,
                    (space - _Slide.blockGap - leadCaption - restCaption) *
                        _leadShare,
                    2 / 3,
                    1,
                  ),
                  shortest([lead], width),
                )
              : _fit(
                  width,
                  space -
                      columnWidth * shape.min -
                      restCaption -
                      _Slide.blockGap -
                      leadCaption,
                  2 / 3,
                  3 / 4,
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CaptionedPhoto(image: lead, height: leadHeight, mode: captions),
              const SizedBox(height: _Slide.blockGap),
              _PhotoRow(
                images: rest,
                photoHeight: rowHeight(
                  rest,
                  space - leadHeight - leadCaption - _Slide.blockGap,
                ),
                mode: captions,
              ),
            ],
          );
        }
        final rows = [
          for (var i = 0; i < images.length; i += 2)
            images.sublist(i, math.min(i + 2, images.length)),
        ];
        final rowSpace =
            (space - _Slide.blockGap * (rows.length - 1)) / rows.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const SizedBox(height: _Slide.blockGap),
              _PhotoRow(
                images: row,
                photoHeight: rowHeight(row, rowSpace),
                mode: captions,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One entry per row: a photo beside its title and note, moving above them
/// when the text's longest word wouldn't fit beside it. [numbered] puts
/// "01" over each title. [divided] (a list slide) puts a rule between
/// entries; [alternating] (a two-entry list, always numbered) swaps the
/// photo to the other side on every second entry.
class _IllustratedList extends StatelessWidget {
  static const double dividerSpacing = 20;

  final List<MagazineCaptionedPhoto> entries;
  final bool numbered;
  final bool alternating;
  final bool divided;
  final double thumbWidth;
  final double thumbHeight;

  const _IllustratedList({
    required this.entries,
    this.numbered = false,
    this.alternating = false,
    this.divided = false,
    required this.thumbWidth,
    required this.thumbHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, entry) in entries.indexed) ...[
          if (i > 0)
            divided
                ? const AppDivider(spacing: dividerSpacing)
                : const SizedBox(height: _Slide.blockGap),
          AdaptiveSideLayout(
            sideEdge: alternating && i.isOdd
                ? AdaptiveSide.trailing
                : AdaptiveSide.leading,
            gap: _Slide.blockGap,
            stackedGap: _Slide.captionGap,
            side: _photo(entry.photo, thumbWidth, thumbHeight),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numbered) ...[
                  EditorialText(
                    (i + 1).toString().padLeft(2, '0'),
                    style: EditorialTypography.editorialNumber,
                  ),
                  const SizedBox(height: _Slide.captionGap),
                ],
                if (entry.title case final title?)
                  EditorialText(title, style: EditorialTypography.itemTitle),
                if (entry.title != null && entry.caption != null)
                  const SizedBox(height: 6),
                if (entry.caption case final caption?)
                  EditorialText(caption, style: EditorialTypography.caption),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Get the Look. One to three pieces with a portrait look: the look on the
/// left (about 58% of the width, only its sides trimmed, so head and shoes
/// stay in), the pieces in a column beside it, both centred on each other.
/// Four to six pieces, a landscape look, or a piece's word too long for that
/// column: the look across the top and the pieces in a grid of square
/// cut-outs under it (two across for four, otherwise up to three), fewer
/// when a name wouldn't fit its column. A look much narrower than its
/// frame there is shown whole (blurred fill) rather than cropped.
///
/// Until the look's own shape is known it is taken as 2:3.
class _Breakdown extends StatelessWidget {
  static const double _lookShare = 0.58;
  static const int _maxBeside = 3;
  static const double _assumedRatio = 3 / 2;

  /// Beside, a look's frame may be up to this much narrower than the photo
  /// (its sides trimmed); its height is never cropped.
  static const double _sideTrim = 0.25;

  /// Below, a photo up to this much taller than its frame is cropped; a
  /// taller one is shown whole.
  static const double _belowCrop = 0.15;

  static const int _minNameChars = 4;

  final MagazinePhoto? look;
  final List<MagazineBreakdownPiece> pieces;

  /// The height the breakdown should come close to filling.
  final double space;

  const _Breakdown({
    required this.look,
    required this.pieces,
    required this.space,
  });

  static bool _fits(
    BuildContext context,
    List<MagazineBreakdownPiece> pieces,
    double width,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    // CJK wraps anywhere, so a column also needs room for a few characters
    // of a name, or it breaks after every two or three.
    final nameSize = EditorialTypography.productName.style.fontSize!;
    if (scaler.scale(nameSize) * _minNameChars > width) {
      return false;
    }
    return pieces.every(
      (piece) =>
          longestLatinWordWidth(
                _PieceCell.role(piece) ?? '',
                EditorialTypography.sectionLabel.style,
                scaler,
              ) <=
              width &&
          longestLatinWordWidth(
                piece.item.name ?? '',
                EditorialTypography.productName.style,
                scaler,
              ) <=
              width,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PhotoShape(
      photo: look,
      builder: (context, ratio) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final measure = _Measure(context);
          final lookRatio = ratio ?? _assumedRatio;
          final lookWidth = (width - _Slide.columnGap) * _lookShare;
          final pieceWidth = width - _Slide.columnGap - lookWidth;
          if (lookRatio > 1 &&
              pieces.length <= _maxBeside &&
              _fits(context, pieces, pieceWidth)) {
            return _beside(measure, lookRatio, lookWidth, pieceWidth);
          }
          return _below(context, measure, lookRatio, width);
        },
      ),
    );
  }

  Widget _beside(
    _Measure measure,
    double lookRatio,
    double lookWidth,
    double pieceWidth,
  ) {
    final lookHeight = space.clamp(
      lookWidth * lookRatio,
      lookWidth * lookRatio / (1 - _sideTrim),
    );
    final captions = pieces.fold(
      0.0,
      (sum, piece) =>
          sum + _PieceCell.captionHeight(measure, piece, pieceWidth),
    );
    final pieceHeight =
        ((lookHeight - captions - _Slide.blockGap * (pieces.length - 1)) /
                pieces.length)
            .clamp(pieceWidth * 3 / 4, pieceWidth * 5 / 4);
    return Row(
      children: [
        _photo(look, lookWidth, lookHeight),
        const SizedBox(width: _Slide.columnGap),
        SizedBox(
          width: pieceWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, piece) in pieces.indexed) ...[
                if (i > 0) const SizedBox(height: _Slide.blockGap),
                _PieceCell(piece, photoHeight: pieceHeight),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _below(
    BuildContext context,
    _Measure measure,
    double lookRatio,
    double width,
  ) {
    double columnWidth(int columns) =>
        (width - _Slide.columnGap * (columns - 1)) / columns;
    var columns = pieces.length == 4 ? 2 : math.min(pieces.length, 3);
    while (columns > 1 && !_fits(context, pieces, columnWidth(columns))) {
      columns--;
    }
    final cellWidth = columnWidth(columns);
    final rows = [
      for (var i = 0; i < pieces.length; i += columns)
        pieces.sublist(i, math.min(i + columns, pieces.length)),
    ];
    final captions = rows.fold(
      0.0,
      (sum, row) =>
          sum +
          row
              .map((p) => _PieceCell.captionHeight(measure, p, cellWidth))
              .reduce(math.max),
    );
    final gaps = _Slide.blockGap * rows.length;
    // Square cut-outs, a little shorter when that keeps the look at 4:3 on
    // screen; one column (a long word at a large text size) would otherwise
    // make every cut-out as tall as the screen is wide.
    final tallest = math.min(cellWidth, width * 0.6);
    final double photoHeight =
        ((space - width * 3 / 4 - gaps - captions) / rows.length).clamp(
          math.min(cellWidth * 3 / 4, tallest),
          tallest,
        );
    final gridHeight =
        photoHeight * rows.length + captions + gaps - _Slide.blockGap;
    // Never taller than the photo itself: that would crop a landscape
    // look's sides for nothing.
    final lookHeight = _fit(
      width,
      space - _Slide.blockGap - gridHeight,
      3 / 4,
      lookRatio.clamp(3 / 4, 5 / 4),
    );
    final whole = lookRatio > lookHeight / width * (1 + _belowCrop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photo(whole ? _shownWhole(look) : look, width, lookHeight),
        const SizedBox(height: _Slide.blockGap),
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: _Slide.blockGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: _Slide.columnGap),
                Expanded(
                  child: c < row.length
                      ? _PieceCell(row[c], photoHeight: photoHeight)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  static MagazinePhoto? _shownWhole(MagazinePhoto? photo) => switch (photo) {
    null => null,
    MagazinePhoto(whole: true) => photo,
    MagazinePhoto(isAsset: true) => MagazinePhoto.asset(
      photo.url,
      focalX: photo.focalX,
      focalY: photo.focalY,
      zoom: photo.zoom,
      whole: true,
    ),
    _ => MagazinePhoto(
      url: photo.url,
      cacheKey: photo.cacheKey,
      focalX: photo.focalX,
      focalY: photo.focalY,
      zoom: photo.zoom,
      whole: true,
    ),
  };
}

/// Builds with [photo]'s own shape (height / width) once its image has
/// loaded — usually at once, as the reader preloads the next slides — and
/// null before then, or when it can't be read (a failed load; the CMS on
/// the web, where a signed image's pixels aren't readable cross-origin).
class _PhotoShape extends StatefulWidget {
  final MagazinePhoto? photo;
  final Widget Function(BuildContext context, double? ratio) builder;

  const _PhotoShape({required this.photo, required this.builder});

  @override
  State<_PhotoShape> createState() => _PhotoShapeState();
}

class _PhotoShapeState extends State<_PhotoShape> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _ratio;
  bool _adding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_PhotoShape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo?.url != widget.photo?.url) {
      _ratio = null;
      _resolve();
    }
  }

  void _resolve() {
    final photo = widget.photo;
    if (photo == null || (kIsWeb && !photo.isAsset)) {
      _stopListening();
      return;
    }
    final ImageProvider provider = photo.isAsset
        ? AssetImage(photo.url)
        : CachedNetworkImageProvider(photo.url, cacheKey: photo.cacheKey);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stopListening();
    final listener = ImageStreamListener((info, _) {
      final ratio = info.image.height / info.image.width;
      if (ratio == _ratio || !mounted) return;
      // A cached image answers inside addListener, before the first build.
      if (_adding) {
        _ratio = ratio;
      } else {
        setState(() => _ratio = ratio);
      }
    }, onError: (_, _) {});
    _adding = true;
    _stream = stream..addListener(listener);
    _adding = false;
    _listener = listener;
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ratio);
}

/// One breakdown piece: its cut-out, then its role in section-label type
/// and the item's name under it.
class _PieceCell extends StatelessWidget {
  static const double _roleGap = 2;

  final MagazineBreakdownPiece piece;
  final double photoHeight;

  const _PieceCell(this.piece, {required this.photoHeight});

  static String? role(MagazineBreakdownPiece piece) =>
      piece.label?.toUpperCase();

  /// The caption's height at [width], with its gap above.
  static double captionHeight(
    _Measure measure,
    MagazineBreakdownPiece piece,
    double width,
  ) {
    final role = _PieceCell.role(piece);
    final name = piece.item.name;
    if (role == null && name == null) return 0;
    return _Slide.captionGap +
        measure.text(role, EditorialTypography.sectionLabel, width) +
        (role != null && name != null ? _roleGap : 0) +
        measure.text(name, EditorialTypography.productName, width);
  }

  @override
  Widget build(BuildContext context) {
    final role = _PieceCell.role(piece);
    final name = piece.item.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _productPhoto(piece.item.photo, double.infinity, photoHeight),
        if (role != null || name != null)
          const SizedBox(height: _Slide.captionGap),
        if (role != null)
          EditorialText(role, style: EditorialTypography.sectionLabel),
        if (role != null && name != null) const SizedBox(height: _roleGap),
        if (name != null)
          EditorialText(name, style: EditorialTypography.productName),
      ],
    );
  }
}

/// A detail page's colours in one row of equal chips, their names on a line
/// below.
class _SwatchRow extends StatelessWidget {
  final List<MagazineSwatch> swatches;
  final double height;

  const _SwatchRow(this.swatches, {required this.height});

  @override
  Widget build(BuildContext context) {
    final names = swatches.map((s) => s.name).nonNulls.join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, swatch) in swatches.indexed) ...[
              if (i > 0) const SizedBox(width: _Slide.captionGap),
              Expanded(
                child: Semantics(
                  label: swatch.name,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: Color(swatch.argb),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (names.isNotEmpty) ...[
          const SizedBox(height: _Slide.captionGap),
          ExcludeSemantics(
            child: EditorialText(names, style: EditorialTypography.caption),
          ),
        ],
      ],
    );
  }
}

/// Under a selection: a nudge to build the look from the reader's own
/// wardrobe, beside the story's cover. The button only shows when the
/// reader wires [onMatchWardrobe] to a real flow.
class _WardrobePrompt extends StatelessWidget {
  final MagazinePhoto? cover;
  final double width;
  final void Function(MagazinePhoto look)? onMatchWardrobe;

  const _WardrobePrompt({
    required this.cover,
    required this.width,
    required this.onMatchWardrobe,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cover = this.cover;
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialText(
          l10n.editorialMakeItYoursTitle,
          style: EditorialTypography.itemTitle,
        ),
        const SizedBox(height: 4),
        EditorialText(
          l10n.editorialMakeItYoursBody,
          style: EditorialTypography.caption,
        ),
      ],
    );
    final thumbWidth = width * 0.3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cover == null)
          copy
        else
          AdaptiveSideLayout(
            sideEdge: AdaptiveSide.leading,
            gap: _Slide.blockGap,
            stackedGap: _Slide.captionGap,
            side: _photo(cover, thumbWidth, thumbWidth * 4 / 3),
            content: copy,
          ),
        if ((cover, onMatchWardrobe) case (final cover?, final onMatch?)) ...[
          const SizedBox(height: _Slide.blockGap),
          _MatchWardrobeButton(onPressed: () => onMatch(cover)),
        ],
      ],
    );
  }
}

class _MatchWardrobeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MatchWardrobeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: AccentPillButton(
        label: AppLocalizations.of(context).exploreMatchYourWardrobe,
        onPressed: onPressed,
        variant: AccentPillButtonVariant.editorial,
      ),
    );
  }
}

/// Display words (a cover title, a typography page's quote): when the
/// longest Latin word can't fit the width at the reader's text scale, they
/// shrink just enough to fit, never below the role's `minFontSize`, rather
/// than split the word.
class _DisplayTitle extends StatelessWidget {
  final String text;
  final EditorialTextStyle style;

  const _DisplayTitle(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widest = longestLatinWordWidth(
          text,
          style.style,
          MediaQuery.textScalerOf(context),
        );
        final size = style.style.fontSize!;
        final fitted = widest > constraints.maxWidth
            ? (size * constraints.maxWidth / widest).clamp(
                style.minFontSize ?? size,
                size,
              )
            : size;
        return EditorialText(
          text,
          style: style.merge(TextStyle(fontSize: fitted)),
        );
      },
    );
  }
}

/// Copy laid over a photo, as on a cover: label, display title and
/// subtitle, light.
class _OverlayCopy extends StatelessWidget {
  /// A sponsored story's label, above everything else.
  final Widget? disclosure;
  final String? label;
  final String? title;
  final String? body;

  const _OverlayCopy({this.disclosure, this.label, this.title, this.body});

  @override
  Widget build(BuildContext context) {
    const surface = EditorialSurface.image;
    final label = this.label;
    final title = this.title;
    final body = this.body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (disclosure case final disclosure?) ...[
          disclosure,
          const SizedBox(height: 12),
        ],
        if (label != null) ...[
          EditorialText(
            label,
            style: EditorialTypography.sectionLabel.on(surface),
          ),
          const SizedBox(height: _Slide.labelGap),
        ],
        if (title != null)
          _DisplayTitle(
            title,
            style: EditorialTypography.coverTitle.on(surface),
          ),
        if (title != null && body != null)
          const SizedBox(height: _Slide.labelGap),
        if (body != null)
          EditorialText(
            body,
            style: EditorialTypography.coverSubtitle.on(surface),
          ),
      ],
    );
  }
}

/// A full-screen photo with its copy at the top or bottom, over a gradient
/// that reaches only a little beyond the copy. The copy is capped at half
/// the screen and scrolls beyond that.
class _OverlayCopyLayout extends StatelessWidget {
  final MagazinePhoto? photo;
  final EdgeInsets padding;
  final MagazineSlideTextPosition textPosition;
  final Widget copy;

  const _OverlayCopyLayout({
    required this.photo,
    required this.padding,
    required this.textPosition,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final atTop = textPosition == MagazineSlideTextPosition.top;
    return ColoredBox(
      color: AppColors.trueBlack,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            MagazineNetworkPhoto(photo: photo),
            Align(
              alignment: atTop ? Alignment.topLeft : Alignment.bottomLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
                    end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
                    colors: [
                      AppColors.overlayMedium,
                      AppColors.overlayMedium,
                      AppColors.overlayMedium.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        constraints.maxHeight * _Slide.maxOverlayCopyShare +
                        _Slide.overlayFade,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      _Slide.inset + padding.left,
                      atTop ? padding.top + _Slide.inset : _Slide.overlayFade,
                      _Slide.inset + padding.right,
                      atTop
                          ? _Slide.overlayFade
                          : _Slide.inset + padding.bottom,
                    ),
                    child: SizedBox(width: double.infinity, child: copy),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Words only, a little above the middle of the screen (scrolling when
/// large text outgrows it): an optional chapter number over the heading,
/// who said it, and the body under a rule.
class _TypographyLayout extends StatelessWidget {
  final MagazineTypographySlide slide;
  final String? label;
  final EdgeInsets padding;

  const _TypographyLayout({
    required this.slide,
    required this.label,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final dark = slide.tone == MagazineSlideTone.dark;
    final surface = dark ? EditorialSurface.dark : EditorialSurface.page;
    final label = this.label;
    final number = slide.number;
    final body = slide.body;
    final scrollPadding = EdgeInsets.fromLTRB(
      _Slide.inset + padding.left,
      padding.top + _Slide.inset,
      _Slide.inset + padding.right,
      padding.bottom + _Slide.inset,
    );
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          EditorialText(
            label,
            style: EditorialTypography.sectionLabel.on(surface),
          ),
          const SizedBox(height: _Slide.blockGap),
        ],
        if (number != null) ...[
          EditorialText(
            number,
            style: EditorialTypography.chapterNumber.on(surface),
          ),
          const SizedBox(height: _Slide.blockGap),
        ],
        _DisplayTitle(
          slide.heading!,
          style: EditorialTypography.quote.on(surface),
        ),
        if (slide.attribution case final attribution?) ...[
          const SizedBox(height: _Slide.blockGap),
          EditorialText(
            '— $attribution',
            style: EditorialTypography.subtitle.on(surface),
          ),
        ],
        if (body != null) ...[
          if (number == null)
            AppDivider(
              spacing: 24,
              color: dark ? AppColors.onPhotoMuted : AppColors.borderStrong,
            )
          else
            const SizedBox(height: _Slide.labelGap),
          EditorialText(body, style: EditorialTypography.body.on(surface)),
        ],
      ],
    );
    return ColoredBox(
      color: dark ? _Slide.darkPage : AppColors.pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: scrollPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - scrollPadding.vertical,
              ),
            ),
            child: Align(
              alignment: const Alignment(-1, -0.2),
              child: SizedBox(width: double.infinity, child: copy),
            ),
          ),
        ),
      ),
    );
  }
}
