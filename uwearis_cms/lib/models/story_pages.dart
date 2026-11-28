import 'package:uwearis/data/magazine.dart';

import 'admin_models.dart';
import 'story_draft.dart';

/// Limits from the backend's `schemas/magazine.py` (contract:
/// docs/magazine_cms.md), checked here so the editor can say what's wrong
/// before saving.
abstract final class PageLimits {
  static const int maxPages = 20;
  static const int minPublishedPages = 2;
  static const int label = 30;
  static const int heading = 60;
  static const int quote = 120;
  static const int body = 200;
  static const int info = 40;
  static const int imageTitle = 40;
  static const int imageCaption = 120;
  static const int pieceLabel = 20;
  static const int attribution = 60;
  static const int number = 4;
  static const int maxDetails = 3;
  static const int maxSwatches = 6;
  static const int maxPieces = 6;
  static const int maxItems = 4;
  static const int minGallery = 2;
  static const int maxGallery = 4;
  static const int minList = 2;
  static const int maxList = 3;
}

/// The eight story layouts, with the editor's names for them.
enum PageLayout {
  immersive('immersive', 'Immersive', '全螢幕照片，文字疊在圖上'),
  feature('feature', 'Feature', '一張主圖，文字在圖上方或下方；也用來介紹品牌'),
  detail('detail', 'Detail', '細節、材質、色票'),
  gallery('gallery', 'Gallery', '2–4 張圖：並排、主圖＋兩張、2×2'),
  list('list', 'Illustrated List', '2–3 項，左圖右文（步驟、技巧、推薦）；2 項時圖文左右交錯、固定編號'),
  breakdown('breakdown', 'Breakdown', '一套穿搭與它的 1–6 件單品'),
  typography('typography', 'Typography', '純文字：理念、引言、章節轉場'),
  selection('selection', 'Selection', '1–4 件商品');

  final String apiValue;
  final String label;
  final String hint;
  const PageLayout(this.apiValue, this.label, this.hint);
}

/// One photo on a page: the uploaded object, where to crop around, and an
/// optional title and caption.
class PageImageDraft {
  String? objectName;
  double focalX;
  double focalY;

  /// 1…2: how far the photo is enlarged inside its frame.
  double zoom;

  /// Shown whole over a blurred copy of itself instead of filling the frame.
  bool whole;
  final Bilingual title;
  final Bilingual caption;

  /// From an imported draft: what photo to find for this spot. Shown in the
  /// editor only, never saved.
  final String? brief;

  PageImageDraft({
    this.objectName,
    this.focalX = 0,
    this.focalY = 0,
    this.zoom = 1,
    this.whole = false,
    Bilingual? title,
    Bilingual? caption,
    this.brief,
  }) : title = title ?? Bilingual(),
       caption = caption ?? Bilingual();

  factory PageImageDraft.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return PageImageDraft(
      objectName: map['object_name'] as String?,
      focalX: (map['focal_x'] as num?)?.toDouble() ?? 0,
      focalY: (map['focal_y'] as num?)?.toDouble() ?? 0,
      zoom: (map['zoom'] as num?)?.toDouble() ?? 1,
      whole: map['fit'] == 'whole',
      title: Bilingual.fromJson(map['title']),
      caption: Bilingual.fromJson(map['caption']),
      brief: map['brief'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'object_name': objectName,
    if (focalX != 0) 'focal_x': focalX,
    if (focalY != 0) 'focal_y': focalY,
    if (zoom != 1) 'zoom': zoom,
    if (whole) 'fit': 'whole',
    if (!title.isEmpty) 'title': title.toJson(),
    if (!caption.isEmpty) 'caption': caption.toJson(),
  };
}

class SwatchDraft {
  String hex;
  final Bilingual name;

  SwatchDraft({this.hex = '#8B7A63', Bilingual? name})
    : name = name ?? Bilingual();

  static final RegExp _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  bool get isValid => _hex.hasMatch(hex);

  Map<String, dynamic> toJson() => {
    'hex': hex.toUpperCase(),
    if (!name.isEmpty) 'name': name.toJson(),
  };
}

class PieceDraft {
  final Bilingual label;
  int? itemId;

  PieceDraft({Bilingual? label, this.itemId}) : label = label ?? Bilingual();

  Map<String, dynamic> toJson() => {
    if (!label.isEmpty) 'label': label.toJson(),
    'featured_item_id': itemId,
  };
}

/// An editable story page. [key] is the stable id the CMS sends as the
/// page's `id` (the backend stores it but never reads it).
sealed class PageDraft {
  final String key;
  final Bilingual label;
  final Bilingual heading;
  final Bilingual body;

  PageDraft({
    String? key,
    Bilingual? label,
    Bilingual? heading,
    Bilingual? body,
  }) : key = key ?? newDraftKey(),
       label = label ?? Bilingual(),
       heading = heading ?? Bilingual(),
       body = body ?? Bilingual();

  PageLayout get layout;

  /// Every photo the page uses, for the rights check.
  List<PageImageDraft> get images;

  Map<String, dynamic> _fields();

  Map<String, dynamic> toJson() => {
    'id': key,
    'layout': layout.apiValue,
    if (!label.isEmpty) 'label': label.toJson(),
    if (!heading.isEmpty) 'heading': heading.toJson(),
    if (!body.isEmpty) 'body': body.toJson(),
    ..._fields(),
  };

  static PageDraft create(PageLayout layout) => switch (layout) {
    PageLayout.immersive => ImmersivePageDraft(),
    PageLayout.feature => FeaturePageDraft(),
    PageLayout.detail => DetailPageDraft(details: [PageImageDraft()]),
    PageLayout.gallery => GalleryPageDraft(
      images: [PageImageDraft(), PageImageDraft()],
    ),
    PageLayout.list => ListPageDraft(
      entries: [PageImageDraft(), PageImageDraft()],
    ),
    PageLayout.breakdown => BreakdownPageDraft(),
    PageLayout.typography => TypographyPageDraft(),
    PageLayout.selection => SelectionPageDraft(),
  };

  /// The backend's admin output is always in the eight-layout format (older
  /// pages are converted when read); anything else is dropped.
  static PageDraft? fromJson(Map<String, dynamic> json) {
    final key = json['id'] as String?;
    final label = Bilingual.fromJson(json['label']);
    final heading = Bilingual.fromJson(json['heading']);
    final body = Bilingual.fromJson(json['body']);
    List<PageImageDraft> images(String field) => [
      for (final image in (json[field] as List?) ?? const [])
        PageImageDraft.fromJson(image),
    ];
    List<int> ids(Object? list) => [
      for (final id in (list as List?) ?? const []) (id as num).toInt(),
    ];
    final textPosition = json['text_position'] == 'top'
        ? MagazineSlideTextPosition.top
        : MagazineSlideTextPosition.bottom;
    return switch (json['layout']) {
      'immersive' => ImmersivePageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        image: PageImageDraft.fromJson(json['image']),
        textPosition: textPosition,
      ),
      'feature' => FeaturePageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        image: PageImageDraft.fromJson(json['image']),
        info: Bilingual.fromJson(json['info']),
        caption: Bilingual.fromJson(json['caption']),
        imageRatio:
            MagazineImageRatio.fromApiValue(json['image_ratio'] as String?) ??
            MagazineImageRatio.portrait,
        textPosition: json['text_position'] == 'bottom'
            ? MagazineSlideTextPosition.bottom
            : MagazineSlideTextPosition.top,
      ),
      'detail' => DetailPageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        main: json['image'] == null
            ? null
            : PageImageDraft.fromJson(json['image']),
        details: images('details'),
        swatches: [
          for (final swatch in (json['swatches'] as List?) ?? const [])
            SwatchDraft(
              hex: (swatch as Map<String, dynamic>)['hex'] as String,
              name: Bilingual.fromJson(swatch['name']),
            ),
        ],
      ),
      'gallery' => GalleryPageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        images: images('images'),
        numbered: json['numbered'] == true,
        square: json['image_ratio'] == 'square',
      ),
      'list' => ListPageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        entries: images('entries'),
        numbered: json['numbered'] == true,
      ),
      'breakdown' => BreakdownPageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        image: PageImageDraft.fromJson(json['image']),
        pieces: [
          for (final piece in (json['pieces'] as List?) ?? const [])
            PieceDraft(
              label: Bilingual.fromJson(
                (piece as Map<String, dynamic>)['label'],
              ),
              itemId: (piece['featured_item_id'] as num?)?.toInt(),
            ),
        ],
      ),
      'typography' => TypographyPageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        dark: json['tone'] == 'dark',
        attribution: Bilingual.fromJson(json['attribution']),
        number: json['number'] as String? ?? '',
      ),
      'selection' => SelectionPageDraft(
        key: key,
        label: label,
        heading: heading,
        body: body,
        itemIds: ids(json['featured_item_ids']),
        wardrobePrompt: json['wardrobe_prompt'] == true,
      ),
      _ => null,
    };
  }

  /// What would make the save fail; [n] is the page's number in the story.
  List<String> problems(int n) {
    final at = '第 $n 頁（${layout.label}）';
    String? missing(PageImageDraft image, String what) =>
        image.objectName == null ? '$at$what還沒上傳圖片' : null;
    return [
      ...switch (this) {
        ImmersivePageDraft(:final image) ||
        FeaturePageDraft(:final image) ||
        BreakdownPageDraft(:final image) => [?missing(image, '主圖')],
        DetailPageDraft(:final main, :final details, :final swatches) => [
          if (details.isEmpty && swatches.isEmpty) '$at至少要有一張細節圖或一個色票',
          if (main != null) ?missing(main, '主圖'),
          for (final (i, d) in details.indexed) ?missing(d, '細節圖 ${i + 1} '),
          for (final (i, s) in swatches.indexed)
            if (!s.isValid) '$at色票 ${i + 1} 的色碼要是 #RRGGBB',
        ],
        GalleryPageDraft(:final images) => [
          for (final (i, image) in images.indexed)
            ?missing(image, '第 ${i + 1} 張'),
        ],
        ListPageDraft(:final entries) => [
          for (final (i, entry) in entries.indexed)
            ?missing(entry, '第 ${i + 1} 項'),
        ],
        TypographyPageDraft() => [if (heading.isEmpty) '$at需要主要文字'],
        SelectionPageDraft(:final itemIds) => [
          if (itemIds.isEmpty) '$at至少要選一件商品',
        ],
      },
      if (this case BreakdownPageDraft(:final pieces)) ...[
        if (pieces.isEmpty) '$at至少要有一件單品',
        for (final (i, p) in pieces.indexed)
          if (p.itemId == null) '$at第 ${i + 1} 件還沒選單品',
      ],
    ];
  }

  /// The page as the App would receive it in [locale]; null when the backend
  /// would skip it (no items left, too few photos, no words).
  MagazineSlide? toSlide(
    ContentLocale locale,
    MagazinePhoto? Function(String? objectName) photo,
    MagazineItem? Function(int? id) item,
  ) {
    String? pick(Bilingual text) => text.pick(locale);
    MagazinePhoto? framed(PageImageDraft? image) {
      final p = photo(image?.objectName);
      return p == null
          ? null
          : MagazinePhoto(
              url: p.url,
              cacheKey: p.cacheKey,
              focalX: image!.focalX,
              focalY: image.focalY,
              zoom: image.zoom,
              whole: image.whole,
            );
    }

    MagazineCaptionedPhoto captioned(PageImageDraft image) =>
        MagazineCaptionedPhoto(
          photo: framed(image),
          title: pick(image.title),
          caption: pick(image.caption),
        );
    final label = pick(this.label);
    final heading = pick(this.heading);
    final body = pick(this.body);
    final page = this;
    return switch (page) {
      ImmersivePageDraft(:final image, :final textPosition) =>
        MagazineImmersiveSlide(
          id: key,
          label: label,
          heading: heading,
          body: body,
          photo: framed(image),
          textPosition: textPosition,
        ),
      FeaturePageDraft() => MagazineFeatureSlide(
        id: key,
        label: label,
        heading: heading,
        body: body,
        info: pick(page.info),
        caption: pick(page.caption),
        photo: framed(page.image),
        imageRatio: page.imageRatio,
        textPosition: page.textPosition,
      ),
      DetailPageDraft(:final main, :final details, :final swatches) =>
        details.isEmpty && swatches.isEmpty
            ? null
            : MagazineDetailSlide(
                id: key,
                label: label,
                heading: heading,
                body: body,
                main: main == null || main.objectName == null
                    ? null
                    : captioned(main),
                details: [for (final d in details) captioned(d)],
                swatches: [
                  for (final s in swatches)
                    if (s.isValid)
                      MagazineSwatch(
                        argb:
                            0xFF000000 |
                            int.parse(s.hex.substring(1), radix: 16),
                        name: pick(s.name),
                      ),
                ],
              ),
      GalleryPageDraft(:final images, :final numbered, :final square) =>
        images.length < PageLimits.minGallery
            ? null
            : MagazineGallerySlide(
                id: key,
                label: label,
                heading: heading,
                body: body,
                images: [for (final i in images) captioned(i)],
                numbered: numbered,
                imageRatio: square
                    ? MagazineImageRatio.square
                    : MagazineImageRatio.portrait,
              ),
      ListPageDraft(:final entries, :final numbered) =>
        entries.length < PageLimits.minList
            ? null
            : MagazineListSlide(
                id: key,
                label: label,
                heading: heading,
                body: body,
                entries: [for (final e in entries) captioned(e)],
                numbered: numbered,
              ),
      BreakdownPageDraft(:final image, :final pieces) => switch ([
        for (final p in pieces)
          if (item(p.itemId) case final i?)
            MagazineBreakdownPiece(label: pick(p.label), item: i),
      ]) {
        final resolved when resolved.isNotEmpty => MagazineBreakdownSlide(
          id: key,
          label: label,
          heading: heading,
          body: body,
          look: framed(image),
          pieces: resolved,
        ),
        _ => null,
      },
      TypographyPageDraft(:final dark, :final attribution, :final number) =>
        heading == null
            ? null
            : MagazineTypographySlide(
                id: key,
                label: label,
                heading: heading,
                body: body,
                tone: dark ? MagazineSlideTone.dark : MagazineSlideTone.light,
                attribution: pick(attribution),
                number: number.trim().isEmpty ? null : number.trim(),
              ),
      SelectionPageDraft(:final itemIds, :final wardrobePrompt) => switch ([
        for (final id in itemIds) ?item(id),
      ]) {
        final items when items.isNotEmpty => MagazineSelectionSlide(
          id: key,
          label: label,
          heading: heading,
          body: body,
          items: items,
          wardrobePrompt: wardrobePrompt,
        ),
        _ => null,
      },
    };
  }
}

class ImmersivePageDraft extends PageDraft {
  final PageImageDraft image;
  MagazineSlideTextPosition textPosition;

  ImmersivePageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    PageImageDraft? image,
    this.textPosition = MagazineSlideTextPosition.bottom,
  }) : image = image ?? PageImageDraft();

  @override
  PageLayout get layout => PageLayout.immersive;

  @override
  List<PageImageDraft> get images => [image];

  @override
  Map<String, dynamic> _fields() => {
    'image': image.toJson(),
    'text_position': textPosition.apiValue,
  };
}

class FeaturePageDraft extends PageDraft {
  final PageImageDraft image;
  final Bilingual info;
  final Bilingual caption;
  MagazineImageRatio imageRatio;
  MagazineSlideTextPosition textPosition;

  FeaturePageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    PageImageDraft? image,
    Bilingual? info,
    Bilingual? caption,
    this.imageRatio = MagazineImageRatio.portrait,
    this.textPosition = MagazineSlideTextPosition.top,
  }) : image = image ?? PageImageDraft(),
       info = info ?? Bilingual(),
       caption = caption ?? Bilingual();

  @override
  PageLayout get layout => PageLayout.feature;

  @override
  List<PageImageDraft> get images => [image];

  @override
  Map<String, dynamic> _fields() => {
    'image': image.toJson(),
    if (!info.isEmpty) 'info': info.toJson(),
    if (!caption.isEmpty) 'caption': caption.toJson(),
    'image_ratio': imageRatio.apiValue,
    'text_position': textPosition.apiValue,
  };
}

class DetailPageDraft extends PageDraft {
  PageImageDraft? main;
  final List<PageImageDraft> details;
  final List<SwatchDraft> swatches;

  DetailPageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    this.main,
    List<PageImageDraft>? details,
    List<SwatchDraft>? swatches,
  }) : details = details ?? [],
       swatches = swatches ?? [];

  @override
  PageLayout get layout => PageLayout.detail;

  @override
  List<PageImageDraft> get images => [?main, ...details];

  @override
  Map<String, dynamic> _fields() => {
    'image': ?main?.toJson(),
    'details': [for (final d in details) d.toJson()],
    'swatches': [for (final s in swatches) s.toJson()],
  };
}

class GalleryPageDraft extends PageDraft {
  @override
  final List<PageImageDraft> images;
  bool numbered;

  /// Products and details at 1:1 instead of people at 2:3.
  bool square;

  GalleryPageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    List<PageImageDraft>? images,
    this.numbered = false,
    this.square = false,
  }) : images = images ?? [];

  @override
  PageLayout get layout => PageLayout.gallery;

  @override
  Map<String, dynamic> _fields() => {
    'images': [for (final i in images) i.toJson()],
    'numbered': numbered,
    'image_ratio': square ? 'square' : 'portrait',
  };
}

class ListPageDraft extends PageDraft {
  final List<PageImageDraft> entries;
  bool numbered;

  ListPageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    List<PageImageDraft>? entries,
    this.numbered = false,
  }) : entries = entries ?? [];

  @override
  PageLayout get layout => PageLayout.list;

  @override
  List<PageImageDraft> get images => entries;

  @override
  Map<String, dynamic> _fields() => {
    'entries': [for (final e in entries) e.toJson()],
    'numbered': numbered,
  };
}

class BreakdownPageDraft extends PageDraft {
  final PageImageDraft image;
  final List<PieceDraft> pieces;

  BreakdownPageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    PageImageDraft? image,
    List<PieceDraft>? pieces,
  }) : image = image ?? PageImageDraft(),
       pieces = pieces ?? [];

  @override
  PageLayout get layout => PageLayout.breakdown;

  @override
  List<PageImageDraft> get images => [image];

  @override
  Map<String, dynamic> _fields() => {
    'image': image.toJson(),
    'pieces': [for (final p in pieces) p.toJson()],
  };
}

class TypographyPageDraft extends PageDraft {
  bool dark;
  final Bilingual attribution;
  String number;

  TypographyPageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    this.dark = false,
    Bilingual? attribution,
    this.number = '',
  }) : attribution = attribution ?? Bilingual();

  @override
  PageLayout get layout => PageLayout.typography;

  @override
  List<PageImageDraft> get images => const [];

  @override
  Map<String, dynamic> _fields() => {
    'tone': dark ? 'dark' : 'light',
    if (!attribution.isEmpty) 'attribution': attribution.toJson(),
    if (number.trim().isNotEmpty) 'number': number.trim(),
  };
}

class SelectionPageDraft extends PageDraft {
  final List<int> itemIds;
  bool wardrobePrompt;

  SelectionPageDraft({
    super.key,
    super.label,
    super.heading,
    super.body,
    List<int>? itemIds,
    this.wardrobePrompt = false,
  }) : itemIds = itemIds ?? [];

  @override
  PageLayout get layout => PageLayout.selection;

  @override
  List<PageImageDraft> get images => const [];

  @override
  Map<String, dynamic> _fields() => {
    'featured_item_ids': itemIds,
    'wardrobe_prompt': wardrobePrompt,
  };
}

/// [admin] as the App would receive it in [locale].
MagazineItem previewItem(AdminItem admin, ContentLocale locale) => MagazineItem(
  id: admin.id,
  name: pickLocale(admin.nameZhTw, admin.nameEn, locale),
  brand: admin.brand,
  category: admin.category,
  description: pickLocale(admin.descriptionZhTw, admin.descriptionEn, locale),
  photo: admin.imageUrl == null
      ? null
      : MagazinePhoto(url: admin.imageUrl!, cacheKey: admin.imageObjectName),
  product: admin.product,
);
