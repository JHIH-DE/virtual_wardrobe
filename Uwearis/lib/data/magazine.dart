/// Explore magazine content as `GET /magazine/home` and
/// `GET /magazine/stories/{id}` return it: one language, blocks and pages
/// already resolved. The CMS builds the same models from its own data for
/// preview.
library;

enum MagazineAudience {
  all('all'),
  men('men'),
  women('women');

  final String apiValue;
  const MagazineAudience(this.apiValue);

  static MagazineAudience fromApiValue(String? value) => values.firstWhere(
    (a) => a.apiValue == value,
    orElse: () => MagazineAudience.all,
  );
}

/// How a story is read: an `article` scrolls through blocks, a `story` pages
/// through full-screen slides.
enum MagazineFormat {
  article('article'),
  story('story'),

  /// A format this build can't render (a newer backend); Explore hides it.
  unknown('');

  final String apiValue;
  const MagazineFormat(this.apiValue);

  /// A backend from before formats sends none: those are all articles.
  static MagazineFormat fromApiValue(String? value) => value == null
      ? MagazineFormat.article
      : values.firstWhere(
          (f) => f != unknown && f.apiValue == value,
          orElse: () => MagazineFormat.unknown,
        );
}

enum MagazineSlideTextPosition {
  top('top'),
  bottom('bottom');

  final String apiValue;
  const MagazineSlideTextPosition(this.apiValue);

  static MagazineSlideTextPosition fromApiValue(String? value) =>
      values.firstWhere((p) => p.apiValue == value, orElse: () => bottom);
}

/// The shape a layout gives its photos, from the few each layout allows.
enum MagazineImageRatio {
  portrait('portrait'),
  square('square'),
  landscape('landscape');

  final String apiValue;
  const MagazineImageRatio(this.apiValue);

  static MagazineImageRatio? fromApiValue(String? value) =>
      values.where((r) => r.apiValue == value).firstOrNull;
}

/// A Typography page's background: the page colour or a dark page.
enum MagazineSlideTone {
  light('light'),
  dark('dark');

  final String apiValue;
  const MagazineSlideTone(this.apiValue);

  static MagazineSlideTone fromApiValue(String? value) =>
      values.firstWhere((t) => t.apiValue == value, orElse: () => light);
}

/// A story's commercial relationship. Anything but [none] is labelled on
/// its cover and its card, naming the sponsor.
enum MagazineSponsorship {
  none('none'),

  /// The brand gave the products, unpaid.
  gifted('gifted'),
  collaboration('collaboration'),

  /// Paid.
  advertisement('advertisement');

  final String apiValue;
  const MagazineSponsorship(this.apiValue);

  static MagazineSponsorship fromApiValue(String? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => none);
}

/// What a story's content drew on (a video it summarises, a brand's site).
class MagazineSource {
  final String? title;
  final String url;

  /// `youtube` / `website` / `brand` / `other`.
  final String kind;

  const MagazineSource({required this.url, this.title, this.kind = 'other'});

  static MagazineSource? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    return MagazineSource(
      url: url,
      title: json['title'] as String?,
      kind: json['kind'] as String? ?? 'other',
    );
  }
}

int _id(Object? value) => (value as num).toInt();

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// A signed photo URL plus the backend's stable cache key for it.
class MagazinePhoto {
  final String url;
  final String? cacheKey;

  /// [url] is a bundled asset path, not a URL: Debug Tools' story preview
  /// and tests, which have no backend.
  final bool isAsset;

  /// Where the subject sits, -1…1 on each axis (0, 0 = centre; as Flutter's
  /// `Alignment`). A photo cropped to fill its frame keeps this point in view.
  final double focalX;
  final double focalY;

  /// How far a photo filling its frame is enlarged around its focal point,
  /// 1…2 (1 = just filling the frame).
  final double zoom;

  /// Shown whole inside its frame, the spare space filled with a blurred
  /// enlargement of the same photo, rather than cropped to fill the frame.
  /// [zoom] then enlarges the whole photo.
  final bool whole;

  const MagazinePhoto({
    required this.url,
    this.cacheKey,
    this.focalX = 0,
    this.focalY = 0,
    this.zoom = 1,
    this.whole = false,
  }) : isAsset = false;

  const MagazinePhoto.asset(
    String path, {
    this.focalX = 0,
    this.focalY = 0,
    this.zoom = 1,
    this.whole = false,
  }) : url = path,
       cacheKey = null,
       isAsset = true;

  static MagazinePhoto? fromJson(
    Object? url,
    Object? cacheKey, {
    Object? focalX,
    Object? focalY,
    Object? zoom,
    Object? fit,
  }) => url is String && url.isNotEmpty
      ? MagazinePhoto(
          url: url,
          cacheKey: cacheKey as String?,
          focalX: _focal(focalX),
          focalY: _focal(focalY),
          zoom: ((zoom as num?)?.toDouble() ?? 1).clamp(1.0, 2.0),
          whole: fit == 'whole',
        )
      : null;

  static double _focal(Object? value) =>
      ((value as num?)?.toDouble() ?? 0).clamp(-1.0, 1.0);
}

/// A story photo with its own short title and caption (a gallery photo, a
/// detail, a list entry).
class MagazineCaptionedPhoto {
  final MagazinePhoto? photo;
  final String? title;
  final String? caption;

  const MagazineCaptionedPhoto({this.photo, this.title, this.caption});

  bool get hasText => title != null || caption != null;

  factory MagazineCaptionedPhoto.fromJson(Map<String, dynamic> json) =>
      MagazineCaptionedPhoto(
        photo: _slidePhoto(json),
        title: json['title'] as String?,
        caption: json['caption'] as String?,
      );
}

MagazinePhoto? _slidePhoto(Map<String, dynamic> json) => MagazinePhoto.fromJson(
  json['image_url'],
  json['image_cache_key'],
  focalX: json['focal_x'],
  focalY: json['focal_y'],
  zoom: json['zoom'],
  fit: json['fit'],
);

/// One garment of a Breakdown: a featured item under a short role
/// label ("Outer"). Being an item, it carries the category and try-on photo
/// that Closet Match / Try-On will work from.
class MagazineBreakdownPiece {
  final String? label;
  final MagazineItem item;

  const MagazineBreakdownPiece({this.label, required this.item});

  /// A piece without its item (deleted since) is skipped.
  static MagazineBreakdownPiece? fromJson(Map<String, dynamic> json) =>
      json['item'] is Map<String, dynamic>
      ? MagazineBreakdownPiece(
          label: json['label'] as String?,
          item: MagazineItem.fromJson(json['item'] as Map<String, dynamic>),
        )
      : null;
}

/// A colour on a Detail page: an opaque sRGB value and its name.
class MagazineSwatch {
  /// 0xAARRGGBB, always opaque.
  final int argb;
  final String? name;

  const MagazineSwatch({required this.argb, this.name});

  static final RegExp _hex = RegExp(r'^#?([0-9a-fA-F]{6})$');

  /// `hex` is "#RRGGBB"; a swatch without a valid one is skipped.
  static MagazineSwatch? fromJson(Map<String, dynamic> json) {
    final match = _hex.firstMatch(json['hex'] as String? ?? '');
    if (match == null) return null;
    return MagazineSwatch(
      argb: 0xFF000000 | int.parse(match[1]!, radix: 16),
      name: json['name'] as String?,
    );
  }
}

/// The catalog product a featured item links to; only items with one are
/// buyable.
class MagazineProduct {
  final int id;
  final String brand;
  final String name;
  final int? price;
  final String currency;
  final String? productUrl;
  final bool isAvailable;

  const MagazineProduct({
    required this.id,
    required this.brand,
    required this.name,
    this.price,
    required this.currency,
    this.productUrl,
    required this.isAvailable,
  });

  factory MagazineProduct.fromJson(Map<String, dynamic> json) =>
      MagazineProduct(
        id: _id(json['id']),
        brand: json['brand'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toInt(),
        currency: json['currency'] as String? ?? '',
        productUrl: json['product_url'] as String?,
        isAvailable: json['is_available'] as bool? ?? false,
      );
}

class MagazineItem {
  final int id;
  final String? name;
  final String? brand;
  final String? category;
  final String? description;
  final MagazinePhoto? photo;
  final MagazinePhoto? tryOnPhoto;
  final MagazineProduct? product;

  const MagazineItem({
    required this.id,
    this.name,
    this.brand,
    this.category,
    this.description,
    this.photo,
    this.tryOnPhoto,
    this.product,
  });

  /// Buyable: linked to a product that is still on sale and has a page.
  bool get isShoppable {
    final product = this.product;
    return product != null && product.isAvailable && product.productUrl != null;
  }

  factory MagazineItem.fromJson(Map<String, dynamic> json) => MagazineItem(
    id: _id(json['id']),
    name: json['name'] as String?,
    brand: json['brand'] as String?,
    category: json['category'] as String?,
    description: json['description'] as String?,
    photo: MagazinePhoto.fromJson(json['image_url'], json['image_cache_key']),
    tryOnPhoto: MagazinePhoto.fromJson(
      json['tryon_image_url'],
      json['tryon_image_cache_key'],
    ),
    product: json['product'] is Map<String, dynamic>
        ? MagazineProduct.fromJson(json['product'] as Map<String, dynamic>)
        : null,
  );
}

sealed class MagazineBlock {
  const MagazineBlock();

  /// An unknown block type (a newer backend) is skipped, not an error.
  static MagazineBlock? fromJson(Map<String, dynamic> json) {
    List<MagazineItem> items(Object? list) => [
      for (final item in (list as List?) ?? const [])
        MagazineItem.fromJson(item as Map<String, dynamic>),
    ];
    return switch (json['type']) {
      'heading' => MagazineHeadingBlock(json['text'] as String? ?? ''),
      'paragraph' => MagazineParagraphBlock(json['text'] as String? ?? ''),
      'image' => MagazineImageBlock(
        photo: MagazinePhoto.fromJson(
          json['image_url'],
          json['image_cache_key'],
        ),
        caption: json['caption'] as String?,
      ),
      'item' => MagazineItemBlock(
        MagazineItem.fromJson(json['item'] as Map<String, dynamic>),
      ),
      'item_group' => MagazineItemGroupBlock(
        title: json['title'] as String?,
        items: items(json['items']),
      ),
      _ => null,
    };
  }
}

class MagazineHeadingBlock extends MagazineBlock {
  final String text;
  const MagazineHeadingBlock(this.text);
}

class MagazineParagraphBlock extends MagazineBlock {
  final String text;
  const MagazineParagraphBlock(this.text);
}

class MagazineImageBlock extends MagazineBlock {
  final MagazinePhoto? photo;
  final String? caption;
  const MagazineImageBlock({this.photo, this.caption});
}

class MagazineItemBlock extends MagazineBlock {
  final MagazineItem item;
  const MagazineItemBlock(this.item);
}

class MagazineItemGroupBlock extends MagazineBlock {
  final String? title;
  final List<MagazineItem> items;
  const MagazineItemGroupBlock({this.title, required this.items});
}

/// One page of a `story` after its cover, in one of eight layouts. Every
/// layout may carry a small section [label] ("THE DETAILS"), a heading and a
/// short body; each adds what its layout is about.
///
/// Layout names in the API: `immersive`, `feature`, `detail`, `gallery`,
/// `list`, `breakdown`, `typography`, `selection`. A backend from before
/// the consolidation still sends `full_bleed`, `image_text`, `image_grid`
/// and `products`, read as their successors.
sealed class MagazineSlide {
  /// The layouts this build renders, sent to the backend so it leaves out
  /// stories that would lose pages here.
  static const List<String> supportedLayouts = [
    'immersive',
    'feature',
    'detail',
    'gallery',
    'list',
    'breakdown',
    'typography',
    'selection',
  ];

  final String? id;
  final String? label;
  final String? heading;
  final String? body;

  const MagazineSlide({this.id, this.label, this.heading, this.body});

  /// An unknown layout (a newer backend, a future video page), or a page
  /// left without what its layout is about (a gallery with fewer than two
  /// photos, a selection without items, typography without its words), is
  /// skipped, not an error. Beyond a layout's limit, the rest is dropped.
  static MagazineSlide? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final label = json['label'] as String?;
    final heading = json['heading'] as String?;
    final body = json['body'] as String?;
    List<MagazineCaptionedPhoto> captioned(String key, int max) => [
      for (final image in (json[key] as List?) ?? const [])
        MagazineCaptionedPhoto.fromJson(image as Map<String, dynamic>),
    ].take(max).toList();
    List<MagazineItem> items() => [
      for (final item in (json['items'] as List?) ?? const [])
        MagazineItem.fromJson(item as Map<String, dynamic>),
    ].take(4).toList();
    final textPosition = MagazineSlideTextPosition.fromApiValue(
      json['text_position'] as String?,
    );
    final ratio = MagazineImageRatio.fromApiValue(
      json['image_ratio'] as String?,
    );
    final numbered = json['numbered'] as bool? ?? false;
    return switch (json['layout']) {
      'immersive' || 'full_bleed' => MagazineImmersiveSlide(
        id: id,
        label: label,
        heading: heading,
        body: body,
        photo: _slidePhoto(json),
        textPosition: textPosition,
      ),
      'feature' || 'image_text' => MagazineFeatureSlide(
        id: id,
        label: label,
        heading: heading,
        body: body,
        info: json['info'] as String?,
        photo: _slidePhoto(json),
        caption: json['caption'] as String?,
        imageRatio: ratio ?? MagazineImageRatio.portrait,
        textPosition: json['text_position'] == null
            ? MagazineSlideTextPosition.top
            : textPosition,
      ),
      'detail' => switch ((
        captioned('details', 3),
        [
          for (final swatch in (json['swatches'] as List?) ?? const [])
            ?MagazineSwatch.fromJson(swatch as Map<String, dynamic>),
        ].take(6).toList(),
      )) {
        (final details, final swatches)
            when details.isNotEmpty || swatches.isNotEmpty =>
          MagazineDetailSlide(
            id: id,
            label: label,
            heading: heading,
            body: body,
            main: json['image'] is Map<String, dynamic>
                ? MagazineCaptionedPhoto.fromJson(
                    json['image'] as Map<String, dynamic>,
                  )
                : null,
            details: details,
            swatches: swatches,
          ),
        _ => null,
      },
      'gallery' || 'image_grid' => switch (captioned('images', 4)) {
        final images when images.length >= 2 => MagazineGallerySlide(
          id: id,
          label: label,
          heading: heading,
          body: body,
          images: images,
          numbered: numbered,
          imageRatio: ratio == MagazineImageRatio.square
              ? MagazineImageRatio.square
              : MagazineImageRatio.portrait,
        ),
        _ => null,
      },
      'list' => switch (captioned('entries', 3)) {
        final entries when entries.length >= 2 => MagazineListSlide(
          id: id,
          label: label,
          heading: heading,
          body: body,
          entries: entries,
          numbered: numbered,
        ),
        _ => null,
      },
      'breakdown' => switch ([
        for (final piece in (json['pieces'] as List?) ?? const [])
          ?MagazineBreakdownPiece.fromJson(piece as Map<String, dynamic>),
      ].take(6).toList()) {
        final pieces when pieces.isNotEmpty => MagazineBreakdownSlide(
          id: id,
          label: label,
          heading: heading,
          body: body,
          look: _slidePhoto(json),
          pieces: pieces,
        ),
        _ => null,
      },
      'typography' when heading != null => MagazineTypographySlide(
        id: id,
        label: label,
        heading: heading,
        body: body,
        tone: MagazineSlideTone.fromApiValue(json['tone'] as String?),
        attribution: json['attribution'] as String?,
        number: json['number'] as String?,
      ),
      'selection' || 'products' => switch (items()) {
        final items when items.isNotEmpty => MagazineSelectionSlide(
          id: id,
          label: label,
          heading: heading,
          body: body,
          items: items,
          wardrobePrompt: json['wardrobe_prompt'] as bool? ?? false,
        ),
        _ => null,
      },
      _ => null,
    };
  }
}

/// Immersive: a full-screen photo with the copy over it, at the top or the
/// bottom. The story's cover is drawn the same way from the story itself.
class MagazineImmersiveSlide extends MagazineSlide {
  final MagazinePhoto? photo;
  final MagazineSlideTextPosition textPosition;
  const MagazineImmersiveSlide({
    super.id,
    super.label,
    super.heading,
    super.body,
    this.photo,
    this.textPosition = MagazineSlideTextPosition.bottom,
  });
}

/// Feature: one photo and the copy as its own block, above the photo
/// ([MagazineSlideTextPosition.top], the default) or below it. [info] is a
/// short line under the heading ("TOKYO / EST. 2016" when the heading is a
/// brand's name); [caption] sits under the photo.
class MagazineFeatureSlide extends MagazineSlide {
  final String? info;
  final MagazinePhoto? photo;
  final String? caption;
  final MagazineImageRatio imageRatio;
  final MagazineSlideTextPosition textPosition;
  const MagazineFeatureSlide({
    super.id,
    super.label,
    super.heading,
    super.body,
    this.info,
    this.photo,
    this.caption,
    this.imageRatio = MagazineImageRatio.portrait,
    this.textPosition = MagazineSlideTextPosition.top,
  });
}

/// Detail: close-ups of fabric, cut and finish, and optionally the colours
/// of a look. Any of the main photo, details and swatches may be missing
/// (one of the last two is always there).
class MagazineDetailSlide extends MagazineSlide {
  final MagazineCaptionedPhoto? main;

  /// One to three.
  final List<MagazineCaptionedPhoto> details;

  /// Up to six.
  final List<MagazineSwatch> swatches;

  const MagazineDetailSlide({
    super.id,
    super.label,
    super.heading,
    super.body,
    this.main,
    this.details = const [],
    this.swatches = const [],
  });
}

/// Gallery: two to four photos (looks to compare, a lookbook, scenes), each
/// optionally titled and captioned, [numbered] in order. A photo that failed
/// to sign keeps its place, so the gallery keeps its shape.
class MagazineGallerySlide extends MagazineSlide {
  final List<MagazineCaptionedPhoto> images;
  final bool numbered;

  /// [MagazineImageRatio.portrait] for people, [MagazineImageRatio.square]
  /// for products and details.
  final MagazineImageRatio imageRatio;

  const MagazineGallerySlide({
    super.id,
    super.label,
    super.heading,
    super.body,
    required this.images,
    this.numbered = false,
    this.imageRatio = MagazineImageRatio.portrait,
  });
}

/// Illustrated List: two or three entries, each a photo beside its title and
/// a short note (steps, tips, picks), [numbered] in order.
class MagazineListSlide extends MagazineSlide {
  final List<MagazineCaptionedPhoto> entries;
  final bool numbered;
  const MagazineListSlide({
    super.id,
    super.label,
    super.heading,
    super.body,
    required this.entries,
    this.numbered = false,
  });
}

/// Breakdown: one complete look and the pieces it's made of.
class MagazineBreakdownSlide extends MagazineSlide {
  final MagazinePhoto? look;

  /// One to six (top, bottom, outer, shoes, bag, an accessory).
  final List<MagazineBreakdownPiece> pieces;

  const MagazineBreakdownSlide({
    super.id,
    super.label,
    super.heading,
    super.body,
    this.look,
    required this.pieces,
  });
}

/// Typography: words only. [heading] is the large text (a statement, a
/// quote, a chapter's title); [body] a line under a rule.
class MagazineTypographySlide extends MagazineSlide {
  final MagazineSlideTone tone;

  /// Who said it ("Editorial Note").
  final String? attribution;

  /// A chapter's number as written ("03").
  final String? number;

  const MagazineTypographySlide({
    super.id,
    super.label,
    required String super.heading,
    super.body,
    this.tone = MagazineSlideTone.light,
    this.attribution,
    this.number,
  });
}

/// Selection: one to four items to buy. [wardrobePrompt] closes the page
/// with the nudge to build the look from the reader's own wardrobe.
class MagazineSelectionSlide extends MagazineSlide {
  final List<MagazineItem> items;
  final bool wardrobePrompt;
  const MagazineSelectionSlide({
    super.id,
    super.label,
    super.heading,
    super.body,
    required this.items,
    this.wardrobePrompt = false,
  });
}

class MagazineIssue {
  final int id;
  final String slug;
  final int? issueNumber;
  final String? title;
  final String? subtitle;
  final MagazinePhoto? cover;
  final DateTime? publishedAt;

  const MagazineIssue({
    required this.id,
    required this.slug,
    this.issueNumber,
    this.title,
    this.subtitle,
    this.cover,
    this.publishedAt,
  });

  factory MagazineIssue.fromJson(Map<String, dynamic> json) => MagazineIssue(
    id: _id(json['id']),
    slug: json['slug'] as String? ?? '',
    issueNumber: (json['issue_number'] as num?)?.toInt(),
    title: json['title'] as String?,
    subtitle: json['subtitle'] as String?,
    cover: MagazinePhoto.fromJson(json['cover_url'], json['cover_cache_key']),
    publishedAt: _date(json['published_at']),
  );
}

class MagazineStorySummary {
  final int id;
  final int issueId;
  final String slug;
  final MagazineFormat format;

  /// The story's category line above its title ("STYLE NOTES").
  final String? kicker;
  final String? title;
  final String? subtitle;
  final MagazinePhoto? cover;

  /// Explore's landscape card, when the story has its own; the cover (a
  /// full-screen portrait for a story) otherwise.
  final MagazinePhoto? card;
  final MagazineAudience audience;
  final DateTime? publishedAt;
  final MagazineSponsorship sponsorship;

  /// The brand behind a sponsored story; set whenever [isSponsored].
  final String? sponsorName;

  const MagazineStorySummary({
    required this.id,
    required this.issueId,
    required this.slug,
    this.format = MagazineFormat.article,
    this.kicker,
    this.title,
    this.subtitle,
    this.cover,
    this.card,
    this.audience = MagazineAudience.all,
    this.publishedAt,
    this.sponsorship = MagazineSponsorship.none,
    this.sponsorName,
  });

  bool get isSponsored => sponsorship != MagazineSponsorship.none;

  factory MagazineStorySummary.fromJson(Map<String, dynamic> json) =>
      MagazineStorySummary(
        id: _id(json['id']),
        issueId: _id(json['issue_id']),
        slug: json['slug'] as String? ?? '',
        format: MagazineFormat.fromApiValue(json['format'] as String?),
        kicker: json['kicker'] as String?,
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        cover: MagazinePhoto.fromJson(
          json['cover_url'],
          json['cover_cache_key'],
          focalX: json['cover_focal_x'],
          focalY: json['cover_focal_y'],
          zoom: json['cover_zoom'],
          fit: json['cover_fit'],
        ),
        card: MagazinePhoto.fromJson(
          json['card_url'],
          json['card_cache_key'],
          focalX: json['card_focal_x'],
          focalY: json['card_focal_y'],
          zoom: json['card_zoom'],
          fit: json['card_fit'],
        ),
        audience: MagazineAudience.fromApiValue(json['audience'] as String?),
        publishedAt: _date(json['published_at']),
        sponsorship: MagazineSponsorship.fromApiValue(
          json['sponsorship'] as String?,
        ),
        sponsorName: json['sponsor_name'] as String?,
      );
}

class MagazineStory {
  final MagazineStorySummary summary;

  /// An article's body; empty for a story.
  final List<MagazineBlock> blocks;

  /// A story's slides after its cover; empty for an article.
  final List<MagazineSlide> pages;

  /// Credits: who wrote it, what it drew on, who took the photos (in order
  /// of appearance).
  final String? author;
  final List<MagazineSource> sources;
  final List<String> photoCredits;

  /// The tools behind the AI-generated images, credited apart from the
  /// photographers.
  final List<String> aiImageTools;

  const MagazineStory({
    required this.summary,
    this.blocks = const [],
    this.pages = const [],
    this.author,
    this.sources = const [],
    this.photoCredits = const [],
    this.aiImageTools = const [],
  });

  /// Anything to show under the story's credits.
  bool get hasCredits =>
      author != null ||
      sources.isNotEmpty ||
      photoCredits.isNotEmpty ||
      aiImageTools.isNotEmpty ||
      summary.isSponsored;

  factory MagazineStory.fromJson(Map<String, dynamic> json) => MagazineStory(
    summary: MagazineStorySummary.fromJson(json),
    blocks: [
      for (final block in (json['blocks'] as List?) ?? const [])
        ?MagazineBlock.fromJson(block as Map<String, dynamic>),
    ],
    pages: [
      for (final page in (json['pages'] as List?) ?? const []) ?_page(page),
    ],
    author: json['author'] as String?,
    sources: [
      for (final source in (json['sources'] as List?) ?? const [])
        ?MagazineSource.fromJson(source),
    ],
    photoCredits: [
      for (final credit in (json['photo_credits'] as List?) ?? const [])
        if (credit is String && credit.isNotEmpty) credit,
    ],
    aiImageTools: [
      for (final tool in (json['ai_image_tools'] as List?) ?? const [])
        if (tool is String && tool.isNotEmpty) tool,
    ],
  );

  /// One malformed page (a field of the wrong type, an item without its id)
  /// is skipped like an unknown one, rather than failing the whole story.
  static MagazineSlide? _page(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return MagazineSlide.fromJson(json);
    } on TypeError {
      return null;
    }
  }
}

class MagazineHome {
  final MagazineIssue? issue;
  final List<MagazineStorySummary> stories;

  const MagazineHome({this.issue, this.stories = const []});

  factory MagazineHome.fromJson(Map<String, dynamic> json) => MagazineHome(
    issue: json['issue'] is Map<String, dynamic>
        ? MagazineIssue.fromJson(json['issue'] as Map<String, dynamic>)
        : null,
    stories: [
      for (final story in (json['stories'] as List?) ?? const [])
        if (MagazineStorySummary.fromJson(story as Map<String, dynamic>)
            case final summary when summary.format != MagazineFormat.unknown)
          summary,
    ],
  );
}
