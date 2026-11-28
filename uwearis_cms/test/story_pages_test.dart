import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis_cms/models/admin_models.dart';
import 'package:uwearis_cms/models/story_draft.dart';
import 'package:uwearis_cms/models/story_pages.dart';

const _img = 'dev/_global/magazine/';

/// A story as the backend's admin API returns it: every layout, in the
/// eight-layout format, with both languages.
Map<String, dynamic> _savedStory() => {
  'id': 8,
  'issue_id': 2,
  'slug': 'old-money',
  'format': 'story',
  'kicker_zh_tw': '風格指南',
  'kicker_en': 'Style Guide',
  'title_zh_tw': null,
  'title_en': 'Old Money Sport',
  'subtitle_zh_tw': null,
  'subtitle_en': null,
  'cover_object_name': '${_img}cover.jpg',
  'cover_focal_x': 0.4,
  'cover_focal_y': null,
  'cover_zoom': 1.3,
  'cover_fit': 'whole',
  'card_object_name': '${_img}card.jpg',
  'card_focal_x': 0.2,
  'audience': 'men',
  'status': 'draft',
  'author_name': 'Uwearis Editors',
  'sources': [
    {'kind': 'youtube', 'title': 'Old Money', 'url': 'https://youtu.be/x'},
  ],
  'sponsorship': 'collaboration',
  'sponsor_name': 'KUMO ATELIER',
  'unconfirmed_images': ['${_img}p1.jpg'],
  'blocks': <Object>[],
  'pages': [
    {
      'id': 'p1',
      'layout': 'immersive',
      'heading': {'en': 'The Mood'},
      'image': {
        'object_name': '${_img}p1.jpg',
        'focal_x': -0.5,
        'zoom': 1.5,
        'fit': 'whole',
      },
      'text_position': 'top',
    },
    {
      'id': 'p2',
      'layout': 'feature',
      'label': {'en': 'Brand Spotlight'},
      'heading': {'en': 'KUMO ATELIER'},
      'image': {'object_name': '${_img}p2.jpg'},
      'info': {'en': 'Tokyo / Est. 2016'},
      'caption': {'zh_tw': '秋冬'},
      'image_ratio': 'landscape',
      'text_position': 'bottom',
    },
    {
      'id': 'p3',
      'layout': 'detail',
      'details': [
        {
          'object_name': '${_img}d1.jpg',
          'title': {'en': 'Suede'},
        },
      ],
      'swatches': [
        {
          'hex': '#5B4A3A',
          'name': {'en': 'Brown'},
        },
      ],
    },
    {
      'id': 'p4',
      'layout': 'gallery',
      'numbered': true,
      'image_ratio': 'square',
      'images': [
        {'object_name': '${_img}g1.jpg'},
        {'object_name': '${_img}g2.jpg'},
      ],
    },
    {
      'id': 'p5',
      'layout': 'list',
      'numbered': false,
      'entries': [
        {'object_name': '${_img}l1.jpg'},
        {'object_name': '${_img}l2.jpg'},
      ],
    },
    {
      'id': 'p6',
      'layout': 'breakdown',
      'image': {'object_name': '${_img}look.jpg'},
      'pieces': [
        {
          'label': {'en': 'Outer'},
          'featured_item_id': 3,
        },
      ],
    },
    {
      'id': 'p7',
      'layout': 'typography',
      'heading': {'en': 'Less, but better.'},
      'tone': 'dark',
      'number': '03',
    },
    {
      'id': 'p8',
      'layout': 'selection',
      'featured_item_ids': [3, 99],
      'wardrobe_prompt': true,
    },
  ],
  'image_urls': {
    for (final name in [
      'cover',
      'card',
      'p1',
      'p2',
      'd1',
      'g1',
      'g2',
      'l1',
      'l2',
      'look',
    ])
      '$_img$name.jpg': 'https://signed/$name.jpg',
  },
  'items': [
    {
      'id': 3,
      'name_zh_tw': '外套',
      'name_en': 'Jacket',
      'brand': 'COMOLI',
      'image_object_name': '${_img}item3.jpg',
      'image_url': 'https://signed/item3.jpg',
    },
  ],
};

void main() {
  _importTests();
  test('a saved story reads every layout and sends it back unchanged', () {
    final draft = StoryDraft.fromJson(_savedStory());
    expect(draft.isStory, isTrue);
    expect(draft.kicker.en, 'Style Guide');
    expect(draft.coverFocalX, 0.4);
    expect(draft.sponsorship, Sponsorship.collaboration);
    expect(draft.unconfirmedImages, ['${_img}p1.jpg']);
    expect(draft.pages.map((p) => p.layout), PageLayout.values);

    final json = draft.toJson();
    expect(json['format'], 'story');
    expect(json['blocks'], isEmpty);
    expect(json['cover_focal_x'], 0.4);
    expect(json['cover_focal_y'], isNull);
    expect(json['cover_zoom'], 1.3);
    expect((json['cover_fit'], json['card_fit']), ('whole', null));
    expect(
      (json['card_object_name'], json['card_focal_x'], json['card_zoom']),
      ('${_img}card.jpg', 0.2, null),
    );
    expect((json['kicker_zh_tw'], json['kicker_en']), ('風格指南', 'Style Guide'));
    expect(json['author_name'], 'Uwearis Editors');
    expect(json['sponsorship'], 'collaboration');
    expect(json['sponsor_name'], 'KUMO ATELIER');
    expect(json['sources'], [
      {'kind': 'youtube', 'title': 'Old Money', 'url': 'https://youtu.be/x'},
    ]);
    final pages = json['pages'] as List;
    final saved = _savedStory()['pages'] as List;
    for (final (i, page) in pages.indexed) {
      final expected = Map<String, dynamic>.from(saved[i] as Map);
      final actual = Map<String, dynamic>.from(page as Map);
      // Empty optional texts are dropped; the only defaults added back are
      // the ones the backend stores anyway.
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(actual[key], _filled(value), reason: '${expected['id']}.$key');
      }
    }
  });

  test('an article sends no pages, a story no blocks', () {
    final draft = StoryDraft.fromJson(_savedStory());
    draft.format = MagazineFormat.article;
    final json = draft.toJson();
    expect(json['pages'], isEmpty);
    expect(json['format'], 'article');
  });

  test('problems name the page, counting the cover as page 1', () {
    final draft =
        StoryDraft(issueId: 1, slug: 'ok', format: MagazineFormat.story)
          ..pages.addAll([
            ImmersivePageDraft(),
            DetailPageDraft(swatches: [SwatchDraft(hex: 'brown')]),
            DetailPageDraft(),
            TypographyPageDraft(),
            SelectionPageDraft(),
            BreakdownPageDraft(
              image: PageImageDraft(objectName: 'a.jpg'),
              pieces: [PieceDraft()],
            ),
          ])
          ..sponsorship = Sponsorship.advertisement
          ..sources.add(SourceDraft(url: 'youtu.be/x'));
    expect(draft.validate(), [
      '有商業合作的內容要填合作品牌',
      '第 1 個參考來源的網址要以 http:// 或 https:// 開頭',
      '第 2 頁（Immersive）主圖還沒上傳圖片',
      '第 3 頁（Detail）色票 1 的色碼要是 #RRGGBB',
      '第 4 頁（Detail）至少要有一張細節圖或一個色票',
      '第 5 頁（Typography）需要主要文字',
      '第 6 頁（Selection）至少要選一件商品',
      '第 7 頁（Breakdown）第 1 件還沒選單品',
    ]);
    draft.pages
      ..clear()
      ..addAll([for (var i = 0; i < 21; i++) TypographyPageDraft()]);
    expect(draft.validate().first, '有商業合作的內容要填合作品牌');
    expect(draft.validate(), contains('一篇最多 20 頁（封面不算）'));
  });

  test('the preview is the story the App would get', () {
    final draft = StoryDraft.fromJson(_savedStory());
    final story = draft.toPreview(ContentLocale.zhTw);
    expect(story.summary.format, MagazineFormat.story);
    expect(story.summary.kicker, '風格指南');
    expect(story.summary.cover?.focalX, 0.4);
    expect(story.pages.map((p) => p.id), [
      'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8', //
    ]);
    final immersive = story.pages[0] as MagazineImmersiveSlide;
    expect(immersive.photo?.focalX, -0.5);
    expect(immersive.photo?.zoom, 1.5);
    expect(immersive.photo?.whole, isTrue);
    expect(story.summary.cover?.whole, isTrue);
    expect(story.summary.card?.whole, isFalse);
    expect(story.summary.cover?.zoom, 1.3);
    expect(story.summary.card?.url, 'https://signed/card.jpg');
    expect(story.summary.card?.focalX, 0.2);
    expect(immersive.photo?.url, 'https://signed/p1.jpg');
    final feature = story.pages[1] as MagazineFeatureSlide;
    expect((feature.info, feature.caption), ('Tokyo / Est. 2016', '秋冬'));
    final detail = story.pages[2] as MagazineDetailSlide;
    expect(detail.swatches.single.argb, 0xFF5B4A3A);
    final selection = story.pages[7] as MagazineSelectionSlide;
    expect(selection.items.single.name, '外套', reason: 'item 99 is gone');

    // A page the backend would skip is skipped here too.
    (draft.pages[7] as SelectionPageDraft).itemIds.remove(3);
    expect(
      draft.toPreview(ContentLocale.en).pages.map((p) => p.id),
      isNot(contains('p8')),
    );
  });

  test('the images a reader sees include the shown items\' photos', () {
    final draft = StoryDraft.fromJson(_savedStory());
    expect(draft.readerImageNames, [
      for (final name in [
        'cover',
        'card',
        'p1',
        'p2',
        'd1',
        'g1',
        'g2',
        'l1',
        'l2',
        'look',
        'item3',
      ])
        '$_img$name.jpg',
    ]);
    expect(draft.items[3], isA<AdminItem>());
  });
}

/// What an imported draft looks like: the save format, images still to
/// find described by `brief`.
const _imported = {
  'format': 'story',
  'slug': 'old-money-sport',
  'title_zh_tw': '老錢運動風',
  'cover_brief': '全身街拍，直式',
  'sources': [
    {'kind': 'youtube', 'url': 'https://youtu.be/x'},
  ],
  'pages': [
    {
      'layout': 'feature',
      'heading': {'zh_tw': '從球場走進城市'},
      'image': {'brief': '針織外套＋寬褲'},
    },
    {
      'layout': 'selection',
      'featured_item_ids': [3],
    },
  ],
};

void _importTests() {
  test('an imported draft opens unsaved in this issue, briefs shown but '
      'never sent', () {
    final draft = StoryDraft.fromImport(_imported, issueId: 9);
    expect(
      (draft.id, draft.issueId, draft.status),
      (null, 9, PublishStatus.draft),
    );
    expect(draft.coverBrief, '全身街拍，直式');
    final feature = draft.pages.first as FeaturePageDraft;
    expect(feature.image.brief, '針織外套＋寬褲');
    expect(feature.image.objectName, isNull);
    expect(draft.referencedItemIds, [3]);
    final json = draft.toJson();
    expect(json['issue_id'], 9);
    expect(json.toString(), isNot(contains('brief')));
    expect(draft.validate(), contains('第 2 頁（Feature）主圖還沒上傳圖片'));
  });

  test('anything but a story object is refused with a reason', () {
    expect(
      () => StoryDraft.fromImport(['x'], issueId: 1),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => StoryDraft.fromImport({'pages': 'nope'}, issueId: 1),
      throwsA(isA<FormatException>()),
    );
  });
}

/// The backend fills missing languages with '' in the CMS' JSON.
Object? _filled(Object? value) => switch (value) {
  Map<String, dynamic>(:final keys)
      when keys.every((k) => k == 'zh_tw' || k == 'en') && keys.isNotEmpty =>
    {'zh_tw': value['zh_tw'] ?? '', 'en': value['en'] ?? ''},
  Map<String, dynamic>() => {
    for (final MapEntry(:key, :value) in value.entries)
      if (value != null) key: _filled(value),
  },
  List() => [for (final v in value) _filled(v)],
  _ => value,
};
