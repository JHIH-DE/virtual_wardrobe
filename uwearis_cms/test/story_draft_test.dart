import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis_cms/models/admin_models.dart';
import 'package:uwearis_cms/models/story_draft.dart';

Map<String, dynamic> _savedStory() => {
  'id': 7,
  'issue_id': 2,
  'slug': 'spring-edit',
  'title_zh_tw': '春季',
  'title_en': null,
  'subtitle_zh_tw': null,
  'subtitle_en': 'Light layers',
  'cover_object_name': 'dev/_global/magazine/cover.jpg',
  'audience': 'women',
  'status': 'published',
  'blocks': [
    {
      'id': 'b1',
      'type': 'heading',
      'text': {'zh_tw': '先從外套開始', 'en': 'Start with a shell'},
    },
    {
      'id': 'b2',
      'type': 'paragraph',
      'text': {'zh_tw': '只有中文'},
    },
    {'type': 'paragraph', 'text': {}},
    {
      'id': 'b3',
      'type': 'image',
      'object_name': 'dev/_global/magazine/a.jpg',
      'caption': {'en': 'Cap'},
    },
    {'id': 'b4', 'type': 'item', 'featured_item_id': 3},
    {
      'id': 'b5',
      'type': 'item_group',
      'featured_item_ids': [3, 99],
    },
    {'type': 'video'},
  ],
  'image_urls': {
    'dev/_global/magazine/cover.jpg': 'https://signed/cover',
    'dev/_global/magazine/a.jpg': 'https://signed/a',
  },
  'items': [
    {
      'id': 3,
      'name_zh_tw': '白T',
      'name_en': 'White Tee',
      'brand': 'UNIQLO',
      'image_url': 'https://signed/tee',
      'image_object_name': 'dev/_global/magazine/tee.png',
      'product': {
        'id': 20,
        'brand': 'UNIQLO',
        'name': 'Tee',
        'price': 590,
        'currency': 'TWD',
        'product_url': 'https://shop/tee',
        'is_available': true,
      },
    },
  ],
};

void main() {
  test('parses a saved story and keeps block ids', () {
    final draft = StoryDraft.fromJson(_savedStory());
    expect(draft.id, 7);
    expect(draft.audience, MagazineAudience.women);
    expect(draft.status, PublishStatus.published);
    // The unknown "video" block is dropped.
    expect(draft.blocks.length, 6);
    expect(draft.blocks.first.key, 'b1');
    expect(draft.items[3]?.product?.price, 590);
  });

  test('preview mirrors the backend: fallback language, skipped blocks', () {
    final draft = StoryDraft.fromJson(_savedStory());

    final en = draft.toPreview(ContentLocale.en);
    expect(en.summary.title, '春季', reason: 'no English title → Chinese');
    expect(en.summary.subtitle, 'Light layers');
    expect(en.summary.cover?.url, 'https://signed/cover');
    expect(en.blocks.map((b) => b.runtimeType), [
      MagazineHeadingBlock,
      MagazineParagraphBlock,
      MagazineImageBlock,
      MagazineItemBlock,
      MagazineItemGroupBlock,
    ]);
    expect((en.blocks[0] as MagazineHeadingBlock).text, 'Start with a shell');
    expect((en.blocks[1] as MagazineParagraphBlock).text, '只有中文');
    final group = en.blocks[4] as MagazineItemGroupBlock;
    expect(group.items.map((i) => i.id), [3], reason: 'item 99 is unknown');
    expect(group.items.single.name, 'White Tee');
    expect(group.items.single.isShoppable, isTrue);

    final zh = draft.toPreview(ContentLocale.zhTw);
    expect((zh.blocks[0] as MagazineHeadingBlock).text, '先從外套開始');
    expect((zh.blocks[3] as MagazineItemBlock).item.name, '白T');
  });

  test(
    'toJson sends every block with its id and drops empty optional texts',
    () {
      final draft = StoryDraft(issueId: 1, slug: ' new-story ')
        ..blocks.addAll([
          HeadingDraft(text: Bilingual(zhTw: '標題')),
          ImageDraft(objectName: 'x.jpg'),
          ItemGroupDraft(itemIds: [1, 2]),
        ]);
      final json = draft.toJson();
      expect(json['slug'], 'new-story');
      final blocks = json['blocks'] as List;
      expect(blocks[0], containsPair('type', 'heading'));
      expect(blocks.every((b) => (b as Map)['id'] is String), isTrue);
      expect((blocks[1] as Map).containsKey('caption'), isFalse);
      expect((blocks[2] as Map).containsKey('title'), isFalse);
      expect((blocks[2] as Map)['featured_item_ids'], [1, 2]);
    },
  );

  test('validate lists what would make the save fail', () {
    final draft = StoryDraft(issueId: 1, slug: 'Bad Slug')
      ..blocks.addAll([
        ImageDraft(),
        ItemDraft(),
        ItemGroupDraft(),
        ParagraphDraft(),
      ]);
    final problems = draft.validate();
    expect(problems.length, 4);
    expect(problems.first, contains('網址代稱'));

    final ok = StoryDraft(issueId: 1, slug: 'good-slug')
      ..blocks.add(ParagraphDraft());
    expect(ok.validate(), isEmpty);
  });
}
