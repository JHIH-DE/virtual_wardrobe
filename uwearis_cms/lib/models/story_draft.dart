import 'dart:math';

import 'package:uwearis/data/magazine.dart';

import 'admin_models.dart';
import 'story_pages.dart';

final _random = Random();

/// A stable key for a new block or page (sent as its `id`).
String newDraftKey() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}';

/// One text in both languages, as the editor holds it.
class Bilingual {
  String zhTw;
  String en;

  Bilingual({this.zhTw = '', this.en = ''});

  factory Bilingual.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return Bilingual(
      zhTw: map['zh_tw'] as String? ?? '',
      en: map['en'] as String? ?? '',
    );
  }

  bool get isEmpty => zhTw.trim().isEmpty && en.trim().isEmpty;

  Map<String, dynamic> toJson() => {'zh_tw': zhTw, 'en': en};

  /// Same fallback as the backend: the reader's language, else the other.
  String? pick(ContentLocale locale) => pickLocale(zhTw, en, locale);
}

/// Which language a preview shows.
enum ContentLocale { zhTw, en }

String? pickLocale(String? zhTw, String? en, ContentLocale locale) {
  final zh = (zhTw ?? '').trim();
  final english = (en ?? '').trim();
  final (first, second) = locale == ContentLocale.zhTw
      ? (zh, english)
      : (english, zh);
  if (first.isNotEmpty) return first;
  if (second.isNotEmpty) return second;
  return null;
}

/// An editable story body block. [key] is the stable id the CMS sends as the
/// block's `id` (the backend stores it but never reads it).
sealed class BlockDraft {
  final String key;

  BlockDraft({String? key}) : key = key ?? newDraftKey();

  String get typeLabel;

  Map<String, dynamic> toJson();

  static BlockDraft? fromJson(Map<String, dynamic> json) {
    final key = json['id'] as String?;
    return switch (json['type']) {
      'heading' => HeadingDraft(
        key: key,
        text: Bilingual.fromJson(json['text']),
      ),
      'paragraph' => ParagraphDraft(
        key: key,
        text: Bilingual.fromJson(json['text']),
      ),
      'image' => ImageDraft(
        key: key,
        objectName: json['object_name'] as String?,
        caption: Bilingual.fromJson(json['caption']),
      ),
      'item' => ItemDraft(
        key: key,
        itemId: (json['featured_item_id'] as num?)?.toInt(),
      ),
      'item_group' => ItemGroupDraft(
        key: key,
        title: Bilingual.fromJson(json['title']),
        itemIds: [
          for (final id in (json['featured_item_ids'] as List?) ?? const [])
            (id as num).toInt(),
        ],
      ),
      _ => null,
    };
  }
}

class HeadingDraft extends BlockDraft {
  final Bilingual text;
  HeadingDraft({super.key, Bilingual? text}) : text = text ?? Bilingual();

  @override
  String get typeLabel => '小標題';

  @override
  Map<String, dynamic> toJson() => {
    'id': key,
    'type': 'heading',
    'text': text.toJson(),
  };
}

class ParagraphDraft extends BlockDraft {
  final Bilingual text;
  ParagraphDraft({super.key, Bilingual? text}) : text = text ?? Bilingual();

  @override
  String get typeLabel => '段落';

  @override
  Map<String, dynamic> toJson() => {
    'id': key,
    'type': 'paragraph',
    'text': text.toJson(),
  };
}

class ImageDraft extends BlockDraft {
  String? objectName;
  final Bilingual caption;
  ImageDraft({super.key, this.objectName, Bilingual? caption})
    : caption = caption ?? Bilingual();

  @override
  String get typeLabel => '圖片';

  @override
  Map<String, dynamic> toJson() => {
    'id': key,
    'type': 'image',
    'object_name': objectName,
    if (!caption.isEmpty) 'caption': caption.toJson(),
  };
}

class ItemDraft extends BlockDraft {
  int? itemId;
  ItemDraft({super.key, this.itemId});

  @override
  String get typeLabel => '單品';

  @override
  Map<String, dynamic> toJson() => {
    'id': key,
    'type': 'item',
    'featured_item_id': itemId,
  };
}

class ItemGroupDraft extends BlockDraft {
  final Bilingual title;
  final List<int> itemIds;
  ItemGroupDraft({super.key, Bilingual? title, List<int>? itemIds})
    : title = title ?? Bilingual(),
      itemIds = itemIds ?? [];

  @override
  String get typeLabel => '單品組';

  @override
  Map<String, dynamic> toJson() => {
    'id': key,
    'type': 'item_group',
    if (!title.isEmpty) 'title': title.toJson(),
    'featured_item_ids': itemIds,
  };
}

/// A story's commercial relationship (backend `MagazineSponsorship`).
enum Sponsorship {
  none('none', '無'),
  gifted('gifted', '品牌提供商品'),
  collaboration('collaboration', '合作內容'),
  advertisement('advertisement', '付費廣告');

  final String apiValue;
  final String label;
  const Sponsorship(this.apiValue, this.label);

  static Sponsorship fromApiValue(Object? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => none);
}

/// Where a story's content came from (backend `MagazineSourceKind`).
enum SourceKind {
  youtube('youtube', 'YouTube'),
  website('website', '網站'),
  brand('brand', '品牌'),
  other('other', '其他');

  final String apiValue;
  final String label;
  const SourceKind(this.apiValue, this.label);

  static SourceKind fromApiValue(Object? value) =>
      values.firstWhere((k) => k.apiValue == value, orElse: () => other);
}

class SourceDraft {
  final String key = newDraftKey();
  SourceKind kind;
  String title;
  String url;

  SourceDraft({this.kind = SourceKind.youtube, this.title = '', this.url = ''});

  static final RegExp _url = RegExp(r'^https?://\S+$');

  bool get isValid => _url.hasMatch(url.trim());

  Map<String, dynamic> toJson() => {
    'kind': kind.apiValue,
    if (title.trim().isNotEmpty) 'title': title.trim(),
    'url': url.trim(),
  };
}

/// The story being edited. Images uploaded in this session keep their
/// preview URL in [imageUrls] until the story is saved.
class StoryDraft {
  final int? id;
  int issueId;
  String slug;

  /// An `article` scrolls through [blocks]; a `story` pages through [pages].
  /// The other list is sent empty.
  MagazineFormat format;
  final Bilingual kicker;
  final Bilingual title;
  final Bilingual subtitle;
  String? coverObjectName;

  /// From an imported draft: what cover photo to find. Never saved.
  String? coverBrief;
  double coverFocalX;
  double coverFocalY;
  double coverZoom;
  bool coverWhole;

  /// Explore's landscape card, when not the cover; with its own crop.
  String? cardObjectName;
  String? cardBrief;
  double cardFocalX;
  double cardFocalY;
  double cardZoom;
  bool cardWhole;
  MagazineAudience audience;
  PublishStatus status;
  final List<BlockDraft> blocks;
  final List<PageDraft> pages;
  String authorName;
  final List<SourceDraft> sources;
  Sponsorship sponsorship;
  String sponsorName;

  /// From the last save: images a reader would see whose usage rights aren't
  /// confirmed yet. Publishing fails while any are left.
  final List<String> unconfirmedImages;
  final Map<String, String> imageUrls;
  final Map<int, AdminItem> items;

  StoryDraft({
    this.id,
    required this.issueId,
    this.slug = '',
    this.format = MagazineFormat.article,
    Bilingual? kicker,
    Bilingual? title,
    Bilingual? subtitle,
    this.coverObjectName,
    this.coverBrief,
    this.coverFocalX = 0,
    this.coverFocalY = 0,
    this.coverZoom = 1,
    this.coverWhole = false,
    this.cardObjectName,
    this.cardBrief,
    this.cardFocalX = 0,
    this.cardFocalY = 0,
    this.cardZoom = 1,
    this.cardWhole = false,
    this.audience = MagazineAudience.all,
    this.status = PublishStatus.draft,
    List<BlockDraft>? blocks,
    List<PageDraft>? pages,
    this.authorName = '',
    List<SourceDraft>? sources,
    this.sponsorship = Sponsorship.none,
    this.sponsorName = '',
    this.unconfirmedImages = const [],
    Map<String, String>? imageUrls,
    Map<int, AdminItem>? items,
  }) : kicker = kicker ?? Bilingual(),
       title = title ?? Bilingual(),
       subtitle = subtitle ?? Bilingual(),
       blocks = blocks ?? [],
       pages = pages ?? [],
       sources = sources ?? [],
       imageUrls = imageUrls ?? {},
       items = items ?? {};

  bool get isStory => format == MagazineFormat.story;

  /// The items the story shows, in [pages] or [blocks] by [format].
  Iterable<int> get referencedItemIds => isStory
      ? pages.expand(
          (page) => switch (page) {
            SelectionPageDraft(:final itemIds) => itemIds,
            BreakdownPageDraft(:final pieces) => [
              for (final piece in pieces) ?piece.itemId,
            ],
            _ => const <int>[],
          },
        )
      : blocks.expand(
          (block) => switch (block) {
            ItemDraft(:final itemId?) => [itemId],
            ItemGroupDraft(:final itemIds) => itemIds,
            _ => const <int>[],
          },
        );

  /// Every image a reader would see, as the backend's publish check counts
  /// them: [imageObjectNames] plus the shown items' photos.
  List<String> get readerImageNames => [
    ...{
      ...imageObjectNames,
      for (final id in referencedItemIds) ?items[id]?.imageObjectName,
    },
  ];

  /// Every image a reader would see that this draft itself places (cover,
  /// blocks, pages), in order; item photos are the items' own.
  List<String> get imageObjectNames => [
    ...{
      ?coverObjectName,
      ?cardObjectName,
      if (isStory)
        for (final page in pages)
          for (final image in page.images) ?image.objectName
      else
        for (final block in blocks)
          if (block case ImageDraft(:final objectName?)) objectName,
    },
  ];

  /// A story written outside the CMS (a draft generated from a video's
  /// notes), in the save format plus image briefs, opened unsaved in
  /// [issueId]. Throws [FormatException] when it isn't a story object.
  factory StoryDraft.fromImport(Object? json, {required int issueId}) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('最外層要是一個 JSON 物件 { ... }');
    }
    try {
      return StoryDraft.fromJson({
        ...json,
        'id': null,
        'issue_id': issueId,
        'slug': json['slug'] ?? '',
        'status': 'draft',
        'unconfirmed_images': const [],
      });
    } on TypeError catch (e) {
      throw FormatException('欄位格式不對：$e');
    }
  }

  factory StoryDraft.fromJson(Map<String, dynamic> json) => StoryDraft(
    id: (json['id'] as num?)?.toInt(),
    issueId: (json['issue_id'] as num).toInt(),
    slug: json['slug'] as String,
    format: json['format'] == 'story'
        ? MagazineFormat.story
        : MagazineFormat.article,
    kicker: Bilingual(
      zhTw: json['kicker_zh_tw'] as String? ?? '',
      en: json['kicker_en'] as String? ?? '',
    ),
    title: Bilingual(
      zhTw: json['title_zh_tw'] as String? ?? '',
      en: json['title_en'] as String? ?? '',
    ),
    subtitle: Bilingual(
      zhTw: json['subtitle_zh_tw'] as String? ?? '',
      en: json['subtitle_en'] as String? ?? '',
    ),
    coverObjectName: json['cover_object_name'] as String?,
    coverBrief: json['cover_brief'] as String?,
    coverFocalX: (json['cover_focal_x'] as num?)?.toDouble() ?? 0,
    coverFocalY: (json['cover_focal_y'] as num?)?.toDouble() ?? 0,
    coverZoom: (json['cover_zoom'] as num?)?.toDouble() ?? 1,
    coverWhole: json['cover_fit'] == 'whole',
    cardObjectName: json['card_object_name'] as String?,
    cardBrief: json['card_brief'] as String?,
    cardFocalX: (json['card_focal_x'] as num?)?.toDouble() ?? 0,
    cardFocalY: (json['card_focal_y'] as num?)?.toDouble() ?? 0,
    cardZoom: (json['card_zoom'] as num?)?.toDouble() ?? 1,
    cardWhole: json['card_fit'] == 'whole',
    authorName: json['author_name'] as String? ?? '',
    sources: [
      for (final source in (json['sources'] as List?) ?? const [])
        SourceDraft(
          kind: SourceKind.fromApiValue((source as Map)['kind']),
          title: source['title'] as String? ?? '',
          url: source['url'] as String? ?? '',
        ),
    ],
    sponsorship: Sponsorship.fromApiValue(json['sponsorship']),
    sponsorName: json['sponsor_name'] as String? ?? '',
    unconfirmedImages: [
      for (final name in (json['unconfirmed_images'] as List?) ?? const [])
        name as String,
    ],
    pages: [
      for (final page in (json['pages'] as List?) ?? const [])
        ?PageDraft.fromJson(page as Map<String, dynamic>),
    ],
    audience: MagazineAudience.fromApiValue(json['audience'] as String?),
    status: PublishStatus.fromApiValue(json['status']),
    blocks: [
      for (final block in (json['blocks'] as List?) ?? const [])
        ?BlockDraft.fromJson(block as Map<String, dynamic>),
    ],
    imageUrls: {
      for (final e in ((json['image_urls'] as Map?) ?? const {}).entries)
        e.key as String: e.value as String,
    },
    items: {
      for (final item in (json['items'] as List?) ?? const [])
        (item['id'] as num).toInt(): AdminItem.fromJson(
          item as Map<String, dynamic>,
        ),
    },
  );

  /// The whole story: the backend's PUT replaces every field, so nothing
  /// may be left out.
  Map<String, dynamic> toJson() => {
    'issue_id': issueId,
    'slug': slug.trim(),
    'format': format.apiValue,
    'kicker_zh_tw': kicker.zhTw,
    'kicker_en': kicker.en,
    'title_zh_tw': title.zhTw,
    'title_en': title.en,
    'subtitle_zh_tw': subtitle.zhTw,
    'subtitle_en': subtitle.en,
    'cover_object_name': coverObjectName,
    'cover_focal_x': coverFocalX == 0 ? null : coverFocalX,
    'cover_focal_y': coverFocalY == 0 ? null : coverFocalY,
    'cover_zoom': coverZoom == 1 ? null : coverZoom,
    'cover_fit': coverWhole ? 'whole' : null,
    'card_object_name': cardObjectName,
    'card_focal_x': cardFocalX == 0 ? null : cardFocalX,
    'card_focal_y': cardFocalY == 0 ? null : cardFocalY,
    'card_zoom': cardZoom == 1 ? null : cardZoom,
    'card_fit': cardWhole ? 'whole' : null,
    'audience': audience.apiValue,
    'blocks': isStory ? const [] : [for (final b in blocks) b.toJson()],
    'pages': isStory ? [for (final p in pages) p.toJson()] : const [],
    'author_name': authorName.trim(),
    'sources': [for (final s in sources) s.toJson()],
    'sponsorship': sponsorship.apiValue,
    'sponsor_name': sponsorName.trim(),
  };

  /// Problems that would make the save fail, shown before sending.
  List<String> validate() => [
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug.trim()))
      '網址代稱只能用小寫英文、數字和 -（例：spring-edit-2026）',
    if (sponsorship != Sponsorship.none && sponsorName.trim().isEmpty)
      '有商業合作的內容要填合作品牌',
    for (final (i, s) in sources.indexed)
      if (!s.isValid) '第 ${i + 1} 個參考來源的網址要以 http:// 或 https:// 開頭',
    if (isStory) ...[
      if (pages.length > PageLimits.maxPages)
        '一篇最多 ${PageLimits.maxPages} 頁（封面不算）',
      for (final (i, page) in pages.indexed) ...page.problems(i + 2),
    ] else
      ...blockProblems(),
  ];

  List<String> blockProblems() => [
    for (final (i, b) in blocks.indexed)
      ...switch (b) {
        ImageDraft(:final objectName) when objectName == null => [
          '第 ${i + 1} 個區塊（圖片）還沒上傳圖片',
        ],
        ItemDraft(:final itemId) when itemId == null => [
          '第 ${i + 1} 個區塊（單品）還沒選單品',
        ],
        ItemGroupDraft(:final itemIds) when itemIds.isEmpty => [
          '第 ${i + 1} 個區塊（單品組）至少要選一個單品',
        ],
        _ => const <String>[],
      },
  ];

  /// The story as the App would receive it in [locale], for the preview.
  /// Mirrors the backend's `resolve_blocks`: empty text and missing items
  /// are skipped.
  MagazineStory toPreview(ContentLocale locale) {
    MagazinePhoto? photo(String? objectName) {
      final url = objectName == null ? null : imageUrls[objectName];
      return url == null ? null : MagazinePhoto(url: url, cacheKey: objectName);
    }

    MagazineItem? item(int? id) {
      final admin = id == null ? null : items[id];
      return admin == null ? null : previewItem(admin, locale);
    }

    final cover = photo(coverObjectName);
    final summary = MagazineStorySummary(
      id: id ?? 0,
      issueId: issueId,
      slug: slug,
      format: format,
      kicker: kicker.pick(locale),
      title: title.pick(locale),
      subtitle: subtitle.pick(locale),
      cover: cover == null
          ? null
          : MagazinePhoto(
              url: cover.url,
              cacheKey: cover.cacheKey,
              focalX: coverFocalX,
              focalY: coverFocalY,
              zoom: coverZoom,
              whole: coverWhole,
            ),
      card: switch (photo(cardObjectName)) {
        final card? => MagazinePhoto(
          url: card.url,
          cacheKey: card.cacheKey,
          focalX: cardFocalX,
          focalY: cardFocalY,
          zoom: cardZoom,
          whole: cardWhole,
        ),
        null => null,
      },
      audience: audience,
    );
    if (isStory) {
      return MagazineStory(
        summary: summary,
        pages: [for (final page in pages) ?page.toSlide(locale, photo, item)],
      );
    }

    final out = <MagazineBlock>[];
    for (final block in blocks) {
      switch (block) {
        case HeadingDraft(:final text):
          final t = text.pick(locale);
          if (t != null) out.add(MagazineHeadingBlock(t));
        case ParagraphDraft(:final text):
          final t = text.pick(locale);
          if (t != null) out.add(MagazineParagraphBlock(t));
        case ImageDraft(:final objectName, :final caption):
          if (objectName != null) {
            out.add(
              MagazineImageBlock(
                photo: photo(objectName),
                caption: caption.pick(locale),
              ),
            );
          }
        case ItemDraft(:final itemId):
          final i = item(itemId);
          if (i != null) out.add(MagazineItemBlock(i));
        case ItemGroupDraft(:final title, :final itemIds):
          final group = [for (final id in itemIds) ?item(id)];
          if (group.isNotEmpty) {
            out.add(
              MagazineItemGroupBlock(title: title.pick(locale), items: group),
            );
          }
      }
    }
    return MagazineStory(summary: summary, blocks: out);
  }
}
