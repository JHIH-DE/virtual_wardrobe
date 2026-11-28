import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/magazine.dart';

Map<String, dynamic> _item(int id, {Map<String, dynamic>? product}) => {
  'id': id,
  'name': 'Item $id',
  'brand': 'UNIQLO',
  'image_url': 'https://x/$id.png',
  'image_cache_key': 'k$id',
  'tryon_image_url': null,
  'product': product,
};

void main() {
  test('story parses every block type and skips unknown ones', () {
    final story = MagazineStory.fromJson({
      'id': 7,
      'issue_id': 2.0,
      'slug': 'spring-edit',
      'title': 'Spring Edit',
      'subtitle': null,
      'cover_url': 'https://x/cover.jpg',
      'cover_cache_key': 'c',
      'audience': 'men',
      'published_at': '2026-11-24T10:00:00+08:00',
      'blocks': [
        {'type': 'heading', 'text': 'Layers'},
        {'type': 'paragraph', 'text': 'Line 1\nLine 2'},
        {'type': 'image', 'image_url': null, 'caption': 'Cap'},
        {'type': 'video', 'url': 'x'},
        {'type': 'item', 'item': _item(1)},
        {
          'type': 'item_group',
          'title': 'Shop',
          'items': [_item(2), _item(3)],
        },
      ],
    });

    expect(story.summary.issueId, 2);
    expect(story.summary.audience, MagazineAudience.men);
    expect(story.summary.cover?.cacheKey, 'c');
    expect(story.summary.publishedAt, isNotNull);
    expect(story.blocks.map((b) => b.runtimeType), [
      MagazineHeadingBlock,
      MagazineParagraphBlock,
      MagazineImageBlock,
      MagazineItemBlock,
      MagazineItemGroupBlock,
    ]);
    expect((story.blocks[2] as MagazineImageBlock).photo, isNull);
    expect((story.blocks[4] as MagazineItemGroupBlock).items.map((i) => i.id), [
      2,
      3,
    ]);
  });

  test('an item is shoppable only while its product is on sale', () {
    final product = {
      'id': 20,
      'brand': 'UNIQLO',
      'name': 'Tee',
      'price': 590.0,
      'currency': 'TWD',
      'product_url': 'https://shop/tee',
      'is_available': true,
    };
    final onSale = MagazineItem.fromJson(_item(1, product: product));
    expect(onSale.isShoppable, isTrue);
    expect(onSale.product?.price, 590);
    expect(
      MagazineItem.fromJson(
        _item(2, product: {...product, 'is_available': false}),
      ).isShoppable,
      isFalse,
    );
    expect(MagazineItem.fromJson(_item(3)).isShoppable, isFalse);
  });

  test('home without a published issue', () {
    final home = MagazineHome.fromJson({'issue': null, 'stories': []});
    expect(home.issue, isNull);
    expect(home.stories, isEmpty);
  });

  test('unknown audience falls back to all', () {
    expect(MagazineAudience.fromApiValue('kids'), MagazineAudience.all);
  });

  Map<String, dynamic> image(String name, {String? title, String? caption}) => {
    'image_url': 'https://x/$name.jpg',
    'image_cache_key': 'k$name',
    'title': ?title,
    'caption': ?caption,
  };

  List<MagazineSlide> pagesOf(List<Map<String, dynamic>> pages) =>
      MagazineStory.fromJson({
        'id': 4,
        'issue_id': 3,
        'slug': 'old-money',
        'format': 'story',
        'pages': pages,
      }).pages;

  test('story format parses the eight layouts', () {
    final story = MagazineStory.fromJson({
      'id': 4,
      'issue_id': 3,
      'slug': 'old-money',
      'format': 'story',
      'kicker': 'STYLE NOTES',
      'title': 'Old Money Sport',
      'cover_url': 'https://x/cover.jpg',
      'cover_focal_x': 0.4,
      'blocks': [],
      'pages': [
        {
          'id': 'p1',
          'layout': 'immersive',
          'label': 'The Mood',
          ...image('a'),
          'text_position': 'top',
        },
        {
          'layout': 'feature',
          'heading': 'KUMO ATELIER',
          'info': 'Tokyo / Est. 2016',
          'caption': 'AW26',
          'image_ratio': 'landscape',
          'focal_x': 0.5,
          'focal_y': -3,
          ...image('b'),
        },
        {
          'layout': 'detail',
          'image': image('main'),
          'details': [image('c', title: 'Suede')],
          'swatches': [
            {'hex': '#5B4A3A', 'name': 'Brown'},
          ],
        },
        {
          'layout': 'gallery',
          'numbered': true,
          'image_ratio': 'square',
          'images': [image('d', title: 'Casual'), image('e')],
        },
        {
          'layout': 'list',
          'numbered': true,
          'entries': [
            image('f', title: 'Adjust the Shape', caption: 'Room to move.'),
            image('g', title: 'Add Layers'),
          ],
        },
        {
          'layout': 'breakdown',
          ...image('look'),
          'pieces': [
            {'label': 'Outer', 'item': _item(1)},
          ],
        },
        {
          'layout': 'typography',
          'heading': 'Less, but better.',
          'tone': 'dark',
          'attribution': 'Editor',
          'number': '03',
        },
        {
          'layout': 'selection',
          'items': [_item(4)],
          'wardrobe_prompt': true,
        },
      ],
    });

    expect(story.summary.format, MagazineFormat.story);
    expect(story.summary.kicker, 'STYLE NOTES');
    expect(story.summary.cover?.focalX, 0.4);
    expect(story.pages.map((p) => p.runtimeType), [
      MagazineImmersiveSlide,
      MagazineFeatureSlide,
      MagazineDetailSlide,
      MagazineGallerySlide,
      MagazineListSlide,
      MagazineBreakdownSlide,
      MagazineTypographySlide,
      MagazineSelectionSlide,
    ]);
    final immersive = story.pages[0] as MagazineImmersiveSlide;
    expect(immersive.id, 'p1');
    expect(immersive.label, 'The Mood');
    expect(immersive.textPosition, MagazineSlideTextPosition.top);
    final feature = story.pages[1] as MagazineFeatureSlide;
    expect(feature.info, 'Tokyo / Est. 2016');
    expect(feature.caption, 'AW26');
    expect(feature.imageRatio, MagazineImageRatio.landscape);
    expect(feature.textPosition, MagazineSlideTextPosition.top);
    expect(feature.photo?.focalX, 0.5);
    expect(feature.photo?.focalY, -1, reason: 'clamped');
    final detail = story.pages[2] as MagazineDetailSlide;
    expect(detail.main?.photo?.cacheKey, 'kmain');
    expect(detail.details.single.title, 'Suede');
    expect(detail.swatches.single.name, 'Brown');
    final gallery = story.pages[3] as MagazineGallerySlide;
    expect(gallery.numbered, isTrue);
    expect(gallery.imageRatio, MagazineImageRatio.square);
    final list = story.pages[4] as MagazineListSlide;
    expect(list.entries.map((e) => e.title), [
      'Adjust the Shape',
      'Add Layers',
    ]);
    final breakdown = story.pages[5] as MagazineBreakdownSlide;
    expect(breakdown.look?.cacheKey, 'klook');
    expect(breakdown.pieces.single.item.id, 1);
    final typography = story.pages[6] as MagazineTypographySlide;
    expect(typography.tone, MagazineSlideTone.dark);
    expect((typography.number, typography.attribution), ('03', 'Editor'));
    expect((story.pages[7] as MagazineSelectionSlide).wardrobePrompt, isTrue);
  });

  test('pages a backend from before the consolidation sends still read', () {
    final pages = pagesOf([
      {'layout': 'full_bleed', ...image('a')},
      {'layout': 'image_text', ...image('b'), 'text_position': 'bottom'},
      {
        'layout': 'image_grid',
        'images': [image('c'), image('d'), image('e')],
      },
      {
        'layout': 'products',
        'items': [_item(1)],
      },
    ]);
    expect(pages.map((p) => p.runtimeType), [
      MagazineImmersiveSlide,
      MagazineFeatureSlide,
      MagazineGallerySlide,
      MagazineSelectionSlide,
    ]);
    expect(
      (pages[0] as MagazineImmersiveSlide).textPosition,
      MagazineSlideTextPosition.bottom,
    );
    expect(
      (pages[1] as MagazineFeatureSlide).textPosition,
      MagazineSlideTextPosition.bottom,
    );
    expect((pages[2] as MagazineGallerySlide).images, hasLength(3));
    expect((pages[3] as MagazineSelectionSlide).wardrobePrompt, isFalse);
  });

  test('a page without what its layout is about is skipped; extras are '
      'dropped', () {
    final pages = pagesOf([
      {
        'layout': 'gallery',
        'images': [image('only')],
      },
      {
        'layout': 'gallery',
        'images': [for (final n in 'abcde'.split('')) image(n)],
      },
      {
        'layout': 'list',
        'entries': [image('only')],
      },
      {
        'layout': 'list',
        'entries': [for (final n in 'abcd'.split('')) image(n)],
      },
      {'layout': 'detail', 'image': image('main')},
      {
        'layout': 'detail',
        'details': [for (final n in 'abcd'.split('')) image(n)],
        'swatches': [
          {'hex': '#12'},
          {'hex': 'olive'},
          for (var i = 0; i < 7; i++) {'hex': '8b9175'},
        ],
      },
      {
        'layout': 'breakdown',
        'pieces': [
          {'label': 'Gone'},
        ],
      },
      {
        'layout': 'breakdown',
        'pieces': [
          for (var i = 1; i <= 7; i++) {'item': _item(i)},
        ],
      },
      {'layout': 'typography', 'body': 'No words'},
      {'layout': 'selection', 'items': []},
      {
        'layout': 'selection',
        'items': [for (var i = 1; i <= 5; i++) _item(i)],
      },
      {'layout': 'video', 'url': 'x'},
      {
        'layout': 'comparison',
        'looks': [image('a'), image('b')],
      },
    ]);
    expect(pages.map((p) => p.runtimeType), [
      MagazineGallerySlide,
      MagazineListSlide,
      MagazineDetailSlide,
      MagazineBreakdownSlide,
      MagazineSelectionSlide,
    ]);
    expect((pages[0] as MagazineGallerySlide).images, hasLength(4));
    expect((pages[1] as MagazineListSlide).entries, hasLength(3));
    final detail = pages[2] as MagazineDetailSlide;
    expect(detail.details, hasLength(3));
    expect(detail.swatches, hasLength(6));
    expect(detail.swatches.first.argb, 0xFF8B9175);
    expect((pages[3] as MagazineBreakdownSlide).pieces, hasLength(6));
    expect((pages[4] as MagazineSelectionSlide).items, hasLength(4));
  });

  test('a malformed page is skipped, not the whole story', () {
    final pages = pagesOf([
      {'layout': 'feature', 'heading': 'Kept'},
      {
        'layout': 'selection',
        'items': [
          {'name': 'No id'},
        ],
      },
      {'layout': 'typography', 'heading': 42},
    ]);
    expect(pages.single.heading, 'Kept');
  });

  test('a photo without a focal point is centred', () {
    final photo = MagazinePhoto.fromJson('https://x/a.jpg', null)!;
    expect((photo.focalX, photo.focalY), (0.0, 0.0));
    expect(MagazinePhoto.fromJson('', 'k'), isNull);
  });

  test('format: missing is an article, unrecognised is unknown', () {
    MagazineFormat parse(Object? format) => MagazineStorySummary.fromJson({
      'id': 1,
      'issue_id': 1,
      'slug': 's',
      'format': ?format,
    }).format;

    expect(parse(null), MagazineFormat.article);
    expect(parse('article'), MagazineFormat.article);
    expect(parse('story'), MagazineFormat.story);
    expect(parse('video'), MagazineFormat.unknown);
    expect(parse(''), MagazineFormat.unknown);
  });

  test('an article has no slides', () {
    final story = MagazineStory.fromJson({
      'id': 1,
      'issue_id': 1,
      'slug': 's',
      'blocks': [
        {'type': 'heading', 'text': 'Hi'},
      ],
    });
    expect(story.summary.format, MagazineFormat.article);
    expect(story.pages, isEmpty);
    expect(story.blocks, hasLength(1));
  });

  test('immersive text sits at the bottom unless told otherwise', () {
    expect(
      MagazineSlideTextPosition.fromApiValue(null),
      MagazineSlideTextPosition.bottom,
    );
    expect(
      MagazineSlideTextPosition.fromApiValue('middle'),
      MagazineSlideTextPosition.bottom,
    );
    expect(MagazineImageRatio.fromApiValue('wide'), isNull);
  });

  test('sponsorship and credits; a home leaves out formats it can\'t read', () {
    final story = MagazineStory.fromJson({
      'id': 4,
      'issue_id': 3,
      'slug': 's',
      'format': 'story',
      'sponsorship': 'advertisement',
      'sponsor_name': 'KUMO ATELIER',
      'author': 'Uwearis Editors',
      'sources': [
        {'kind': 'youtube', 'title': 'Old Money', 'url': 'https://youtu.be/x'},
        {'kind': 'website', 'url': ''},
        'junk',
      ],
      'photo_credits': ['Ken', ''],
      'ai_image_tools': ['Midjourney v7'],
    });
    expect(story.summary.isSponsored, isTrue);
    expect(story.summary.sponsorship, MagazineSponsorship.advertisement);
    expect(story.summary.sponsorName, 'KUMO ATELIER');
    expect(story.author, 'Uwearis Editors');
    expect(story.sources.single.title, 'Old Money');
    expect(story.photoCredits, ['Ken']);
    expect(story.aiImageTools, ['Midjourney v7']);
    expect(
      MagazineStory.fromJson({
        'id': 1,
        'issue_id': 1,
        'slug': 's',
        'ai_image_tools': ['Firefly'],
      }).hasCredits,
      isTrue,
    );
    expect(story.hasCredits, isTrue);
    expect(
      MagazineStory.fromJson({'id': 1, 'issue_id': 1, 'slug': 's'}).hasCredits,
      isFalse,
    );
    expect(MagazineSponsorship.fromApiValue('bribe'), MagazineSponsorship.none);

    final home = MagazineHome.fromJson({
      'stories': [
        {'id': 1, 'issue_id': 1, 'slug': 'a', 'format': 'story'},
        {'id': 2, 'issue_id': 1, 'slug': 'b', 'format': 'video'},
        {'id': 3, 'issue_id': 1, 'slug': 'c'},
      ],
    });
    expect(home.stories.map((s) => s.id), [1, 3]);
  });

  test('zoom is read for page photos and the cover, kept within 1–2', () {
    final story = MagazineStory.fromJson({
      'id': 1,
      'issue_id': 1,
      'slug': 's',
      'format': 'story',
      'cover_url': 'https://x/c.jpg',
      'cover_zoom': 1.4,
      'pages': [
        {'layout': 'immersive', 'image_url': 'https://x/a.jpg', 'zoom': 5},
        {'layout': 'feature', 'image_url': 'https://x/b.jpg'},
      ],
    });
    expect(story.summary.cover?.zoom, 1.4);
    expect((story.pages[0] as MagazineImmersiveSlide).photo?.zoom, 2);
    expect((story.pages[1] as MagazineFeatureSlide).photo?.zoom, 1);
  });

  test('a story may have its own card image', () {
    MagazineStorySummary parse(Map<String, dynamic> extra) =>
        MagazineStorySummary.fromJson({
          'id': 1,
          'issue_id': 1,
          'slug': 's',
          ...extra,
        });
    final withCard = parse({
      'cover_url': 'https://x/cover.jpg',
      'card_url': 'https://x/card.jpg',
      'card_cache_key': 'kc',
      'card_focal_x': -0.3,
      'card_zoom': 1.2,
    });
    expect(withCard.card?.cacheKey, 'kc');
    expect((withCard.card?.focalX, withCard.card?.zoom), (-0.3, 1.2));
    expect(parse({'cover_url': 'https://x/cover.jpg'}).card, isNull);
  });

  test('a photo can be shown whole instead of filling its frame', () {
    final story = MagazineStory.fromJson({
      'id': 1,
      'issue_id': 1,
      'slug': 's',
      'format': 'story',
      'cover_url': 'https://x/c.jpg',
      'cover_fit': 'whole',
      'card_url': 'https://x/k.jpg',
      'pages': [
        {'layout': 'feature', 'image_url': 'https://x/a.jpg', 'fit': 'whole'},
        {'layout': 'feature', 'image_url': 'https://x/b.jpg', 'fit': 'odd'},
      ],
    });
    expect(story.summary.cover?.whole, isTrue);
    expect(story.summary.card?.whole, isFalse);
    expect((story.pages[0] as MagazineFeatureSlide).photo?.whole, isTrue);
    expect((story.pages[1] as MagazineFeatureSlide).photo?.whole, isFalse);
  });
}
