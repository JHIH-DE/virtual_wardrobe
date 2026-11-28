import 'package:flutter/widgets.dart';

import '../../../data/magazine.dart';

// Sample stories for Debug Tools, all on bundled images with no backend.
// This is magazine *content* (what the CMS would supply), not UI copy, so it
// isn't in the ARB files. The mock stories' photos are placeholders (3:2
// landscape street shots and two product cut-outs); focal points keep the
// person in frame where a layout crops. The layout gallery uses line
// drawings instead. KUMO ATELIER is a made-up brand.

/// Three stories as an editor would write them: a style guide, a lookbook
/// and a brand story, each mixing the layouts differently.
List<MagazineStory> editorialMockStories(Locale locale) {
  final c = _Copy(locale.languageCode == 'zh');
  return [_styleGuide(c), _lookbook(c), _brandStory(c)];
}

/// Every layout and its variants in one story, each page's label naming it
/// ("Gallery · 3") so layouts can be discussed by name. For the team only:
/// real stories carry their own labels.
MagazineStory editorialLayoutGallery(Locale locale) {
  final t = _Copy(locale.languageCode == 'zh');
  final jacket = _jacketItem(t, photo: _schematicShirt);
  final sneakers = _sneakersItem(t, photo: _schematicShoes);
  return MagazineStory(
    summary: _summary(
      0,
      kicker: 'Immersive · Cover',
      title: 'Layout Gallery',
      subtitle: t('八種版型與它們的變化。', 'Eight layouts and their variants.'),
      cover: _schematicPortrait,
    ),
    pages: [
      MagazineImmersiveSlide(
        label: 'Immersive · Top',
        heading: t('從土地借來的顏色', 'Colours Borrowed from the Land'),
        body: t('低彩度，讓材質說話。', 'Muted colour lets the fabric speak.'),
        photo: _schematicPortrait,
        textPosition: MagazineSlideTextPosition.top,
      ),
      MagazineFeatureSlide(
        label: 'Feature · Portrait',
        heading: t('城市裡的休閒美學', 'Ease, in the City'),
        body: t('舒適的輪廓，恰到好處的精緻感。', 'An easy shape, finished just enough.'),
        photo: _schematicPortrait,
      ),
      MagazineFeatureSlide(
        label: 'Feature · Landscape · Text Below',
        heading: 'KUMO ATELIER',
        info: 'Tokyo / Est. 2016',
        body: t(
          '自家開發布料，只做少量的日常基本款。',
          'Fabrics developed in-house, made into a few everyday basics.',
        ),
        caption: t('2026 秋冬系列', 'Autumn / Winter 2026'),
        photo: _schematicLandscape,
        imageRatio: MagazineImageRatio.landscape,
        textPosition: MagazineSlideTextPosition.bottom,
      ),
      MagazineDetailSlide(
        label: 'Detail · Main + Swatches',
        heading: t('質感藏在細節裡', 'Quality Lives in the Details'),
        main: const MagazineCaptionedPhoto(photo: _photoShirt),
        swatches: _earthTones(t),
        details: [
          _captioned(_photoShirt, t('麂皮', 'Suede')),
          _captioned(_photoShoes, t('羊毛', 'Wool')),
        ],
      ),
      MagazineDetailSlide(
        label: 'Detail · No Main',
        heading: t('同色系的層次', 'Tone on Tone'),
        body: t('同一個色系，用不同材質做出深淺。', 'One colour; let fabrics set the depth.'),
        swatches: const [
          MagazineSwatch(argb: 0xFF3F3328),
          MagazineSwatch(argb: 0xFF6B5843),
          MagazineSwatch(argb: 0xFF9C8466),
          MagazineSwatch(argb: 0xFFCDBB9E),
        ],
        details: [
          _captioned(_photoShirt, t('羊毛', 'Wool')),
          _captioned(_photoShoes, t('皮革', 'Leather')),
          _captioned(_photoShirt, t('燈芯絨', 'Corduroy')),
        ],
      ),
      MagazineGallerySlide(
        label: 'Gallery · 2',
        heading: t('西裝與帽 T 之間', 'Between a Suit and a Hoodie'),
        images: [
          _captioned(
            _schematicPortrait,
            'Tailored',
            t('西裝外套配寬褲', 'Blazer, wide trousers'),
          ),
          _captioned(
            _schematicPortrait,
            'Relaxed',
            t('工裝外套配軍褲', 'Work jacket, fatigues'),
          ),
        ],
      ),
      MagazineGallerySlide(
        label: 'Gallery · 3',
        heading: t('三種造型', 'Three Looks'),
        numbered: true,
        images: [
          _captioned(_schematicPortrait, 'Smart Casual'),
          _captioned(_schematicPortrait, 'Workwear'),
          _captioned(_schematicPortrait, 'Outdoor'),
        ],
      ),
      MagazineGallerySlide(
        label: 'Gallery · 4',
        heading: t('週末的四種樣貌', 'Four Weekend Looks'),
        images: [
          _captioned(_schematicPortrait, 'Casual'),
          _captioned(_schematicPortrait, 'Outdoor'),
          _captioned(_schematicPortrait, 'Workwear'),
          _captioned(_schematicPortrait, 'Smart Casual'),
        ],
      ),
      MagazineGallerySlide(
        label: 'Gallery · Square',
        heading: t('四個細節', 'Four Details'),
        imageRatio: MagazineImageRatio.square,
        images: [
          _captioned(_photoShirt, t('領口', 'Collar')),
          _captioned(_photoShoes, t('鞋底', 'Sole')),
          _captioned(_photoShirt, t('袖口', 'Cuff')),
          _captioned(_photoShoes, t('縫線', 'Stitching')),
        ],
      ),
      MagazineListSlide(
        label: 'Illustrated List · 3',
        heading: t('三個穿搭重點', 'Three Things to Get Right'),
        numbered: true,
        entries: _tips(t, _schematicPortrait),
      ),
      MagazineListSlide(
        label: 'Illustrated List · 2',
        heading: t('兩種升級方式', 'Two Ways to Upgrade'),
        entries: _tips(t, _schematicPortrait).take(2).toList(),
      ),
      for (final count in [2, 3, 4, 6])
        MagazineBreakdownSlide(
          label: 'Breakdown · $count',
          heading: t('解構一套穿搭', 'One Look, Taken Apart'),
          look: count <= 3 ? _schematicPortrait : _schematicLandscape,
          pieces: _schematicPieces(t, count),
        ),
      MagazineTypographySlide(
        label: 'Typography · Light',
        heading: 'Less, but better.',
        body: t(
          '真正的質感，不需要大聲宣告。',
          'Real quality never needs to announce itself.',
        ),
      ),
      MagazineTypographySlide(
        label: 'Typography · Dark',
        heading: t(
          '「好的衣服，應該成為生活的一部分。」',
          '“Good clothes should become part of your life.”',
        ),
        attribution: 'Editorial Note',
        tone: MagazineSlideTone.dark,
      ),
      MagazineTypographySlide(
        label: 'Typography · Chapter',
        heading: 'The Art of Layering',
        body: t('重新理解層次穿搭。', 'Layering, reconsidered.'),
        number: '03',
      ),
      MagazineSelectionSlide(
        label: 'Selection · Prompt',
        heading: t('值得入手的單品', 'Pieces Worth Having'),
        items: [jacket, sneakers],
        wardrobePrompt: true,
      ),
    ],
  );
}

class _Copy {
  final bool zh;
  const _Copy(this.zh);

  String call(String zhText, String enText) => zh ? zhText : enText;
}

const _cityWalk = MagazinePhoto.asset(
  'assets/images/explore_01.png',
  focalX: 0.43,
);
const _leaning = MagazinePhoto.asset(
  'assets/images/explore_02.png',
  focalX: 0.6,
);
const _trail = MagazinePhoto.asset(
  'assets/images/explore_03.png',
  focalX: 0.55,
);
const _jacket = MagazinePhoto.asset('assets/images/explore_04.png');
const _sneakers = MagazinePhoto.asset('assets/images/explore_05.png');

// The layout gallery is drawn in line drawings instead of photos, so each
// page shows its arrangement rather than a particular look: a figure on grey
// for a person, garments on the product backdrop for pieces and details.
// Product cut-outs are on white, which the product backdrop's multiply turns
// into its colour; the `photo_` ones carry that colour for plain frames.
const _schematicPortrait = MagazinePhoto.asset(
  'assets/images/schematic_look_portrait.png',
);
const _schematicLandscape = MagazinePhoto.asset(
  'assets/images/schematic_look_landscape.png',
);
const _schematicShirt = MagazinePhoto.asset(
  'assets/images/schematic_shirt.png',
);
const _schematicShoes = MagazinePhoto.asset(
  'assets/images/schematic_shoes.png',
);
const _photoShirt = MagazinePhoto.asset(
  'assets/images/schematic_photo_shirt.png',
);
const _photoShoes = MagazinePhoto.asset(
  'assets/images/schematic_photo_shoes.png',
);

/// Two: top and shoes; three adds a bag; four an outer layer; six a watch
/// and glasses.
List<MagazineBreakdownPiece> _schematicPieces(_Copy t, int count) {
  MagazineBreakdownPiece piece(
    int id,
    String icon,
    (String, String) label,
    (String, String) name,
  ) => MagazineBreakdownPiece(
    label: t(label.$1, label.$2),
    item: MagazineItem(
      id: 100 + id,
      name: t(name.$1, name.$2),
      photo: MagazinePhoto.asset('assets/images/schematic_$icon.png'),
    ),
  );
  final top = piece(1, 'shirt', ('上衣', 'Top'), ('襯衫', 'Shirt'));
  final outer = piece(2, 'shirt', ('外套', 'Outer'), ('夾克', 'Jacket'));
  final shoes = piece(3, 'shoes', ('鞋子', 'Shoes'), ('球鞋', 'Sneakers'));
  final bag = piece(4, 'bag', ('包款', 'Bag'), ('托特包', 'Tote'));
  final watch = piece(5, 'watch', ('配件', 'Accessory'), ('手錶', 'Watch'));
  final glasses = piece(6, 'glasses', ('配件', 'Accessory'), ('眼鏡', 'Glasses'));
  return switch (count) {
    2 => [top, shoes],
    3 => [top, shoes, bag],
    4 => [top, outer, shoes, bag],
    _ => [top, outer, shoes, bag, watch, glasses],
  };
}

MagazineCaptionedPhoto _captioned(
  MagazinePhoto photo,
  String title, [
  String? caption,
]) => MagazineCaptionedPhoto(photo: photo, title: title, caption: caption);

MagazineStorySummary _summary(
  int id, {
  required String kicker,
  required String title,
  required String subtitle,
  required MagazinePhoto cover,
}) => MagazineStorySummary(
  id: id,
  issueId: 0,
  slug: 'editorial-preview-$id',
  format: MagazineFormat.story,
  kicker: kicker,
  title: title,
  subtitle: subtitle,
  cover: cover,
);

MagazineItem _jacketItem(
  _Copy t, {
  String brand = 'COMOLI',
  MagazinePhoto photo = _jacket,
}) => MagazineItem(
  id: 1,
  name: t('羊毛針織 Track Jacket', 'Wool Track Jacket'),
  brand: brand,
  category: 'outer',
  photo: photo,
  product: MagazineProduct(
    id: 1,
    brand: brand,
    name: 'Wool Knit Track Jacket',
    price: 38000,
    currency: 'TWD',
    productUrl: 'https://example.com',
    isAvailable: true,
  ),
);

/// No product behind it: no price, nothing to buy.
MagazineItem _sneakersItem(
  _Copy t, {
  String brand = 'Graphpaper',
  MagazinePhoto photo = _sneakers,
}) => MagazineItem(
  id: 2,
  name: t('白色皮革球鞋', 'Leather Sneakers'),
  brand: brand,
  category: 'shoes',
  photo: photo,
);

List<MagazineSwatch> _earthTones(_Copy t) => [
  MagazineSwatch(argb: 0xFF5B4A3A, name: t('深棕', 'Brown')),
  MagazineSwatch(argb: 0xFF8B7A63, name: t('駝色', 'Camel')),
  MagazineSwatch(argb: 0xFFB9A994, name: t('沙色', 'Sand')),
  MagazineSwatch(argb: 0xFFE4DAC8, name: t('奶油', 'Cream')),
];

/// [photo] stands in for all three when given (the layout gallery).
List<MagazineCaptionedPhoto> _tips(_Copy t, [MagazinePhoto? photo]) => [
  _captioned(
    photo ?? _cityWalk,
    t('調整輪廓', 'Adjust the Shape'),
    t('保留舒適的空間。', 'Leave room to move.'),
  ),
  _captioned(
    photo ?? _leaning,
    t('增加層次', 'Add Layers'),
    t('運用不同面料。', 'Mix your fabrics.'),
  ),
  _captioned(
    photo ?? _trail,
    t('選對鞋款', 'Choose the Shoes'),
    t('平衡整體比例。', 'Balance the proportions.'),
  ),
];

/// Style Guide, cover + six: feature, detail, list, gallery of two,
/// selection closing with the wardrobe prompt.
MagazineStory _styleGuide(_Copy t) => MagazineStory(
  summary: _summary(
    1,
    kicker: 'Style Guide',
    title: 'Old Money Sport',
    subtitle: t('低調而精緻的日常。', 'Understated, and finished.'),
    cover: _leaning,
  ),
  pages: [
    MagazineFeatureSlide(
      label: 'The Feature',
      heading: t('從球場走進城市', 'From the Club to the City'),
      body: t(
        '保留運動服的舒適輪廓，以精緻剪裁融入日常。',
        'Keep the easy shape of sportswear; let the cut make it city-ready.',
      ),
      photo: _cityWalk,
    ),
    MagazineDetailSlide(
      label: 'The Details',
      heading: t('質感藏在細節裡', 'Quality Lives in the Details'),
      main: const MagazineCaptionedPhoto(photo: _jacket),
      swatches: _earthTones(t),
      details: [
        _captioned(_jacket, t('羊毛針織', 'Wool Knit')),
        _captioned(_sneakers, t('真皮', 'Leather')),
      ],
    ),
    MagazineListSlide(
      label: 'Style Tips',
      heading: t('三個穿搭重點', 'Three Things to Get Right'),
      numbered: true,
      entries: _tips(t),
    ),
    MagazineGallerySlide(
      label: 'The Styling',
      heading: t('西裝與帽 T 之間', 'Between a Suit and a Hoodie'),
      body: t('不必穿得正式，也能保有精緻感。', 'Polished without being formal.'),
      images: [
        _captioned(
          _cityWalk,
          'Tailored',
          t('西裝外套配寬褲', 'Blazer, wide trousers'),
        ),
        _captioned(_leaning, 'Relaxed', t('工裝外套配軍褲', 'Work jacket, fatigues')),
      ],
    ),
    MagazineTypographySlide(
      heading: 'Less, but better.',
      body: t('真正的質感，不需要大聲宣告。', 'Real quality never needs to announce itself.'),
    ),
    MagazineSelectionSlide(
      label: 'The Selection',
      heading: t('從一件開始', 'Start with One Piece'),
      items: [_jacketItem(t), _sneakersItem(t)],
      wardrobePrompt: true,
    ),
  ],
);

/// Lookbook, cover + four: galleries of four and three, then two
/// breakdowns (pieces beside the look, then below it). No selection.
MagazineStory _lookbook(_Copy t) {
  final jacket = _jacketItem(t);
  final sneakers = _sneakersItem(t);
  return MagazineStory(
    summary: _summary(
      2,
      kicker: 'Lookbook',
      title: t('週末的四種樣貌', 'Four Ways to Do the Weekend'),
      subtitle: t('同一個衣櫃，四種週末。', 'One wardrobe, four weekends.'),
      cover: _trail,
    ),
    pages: [
      MagazineGallerySlide(
        label: 'The Lookbook',
        heading: t('週末的四種樣貌', 'Four Weekend Looks'),
        numbered: true,
        images: [
          _captioned(_cityWalk, 'Casual'),
          _captioned(_trail, 'Outdoor'),
          _captioned(_leaning, 'Workwear'),
          _captioned(_cityWalk, 'Smart Casual'),
        ],
      ),
      MagazineGallerySlide(
        label: 'Rainy Days',
        heading: t('下雨天的三種選擇', 'Three for a Rainy Day'),
        images: [
          _captioned(_trail, t('戶外', 'Trail'), t('機能外套', 'Technical shell')),
          _captioned(
            _cityWalk,
            t('城市', 'City'),
            t('單排扣大衣', 'Single-breasted coat'),
          ),
          _captioned(_leaning, t('通勤', 'Commute'), t('工裝外套', 'Work jacket')),
        ],
      ),
      MagazineBreakdownSlide(
        label: 'Get the Look',
        heading: t('解構一套穿搭', 'One Look, Taken Apart'),
        look: _leaning,
        pieces: [
          MagazineBreakdownPiece(label: 'Outer', item: jacket),
          MagazineBreakdownPiece(label: 'Shoes', item: sneakers),
        ],
      ),
      MagazineBreakdownSlide(
        label: 'Get the Look',
        heading: t('週日的城市', 'Sunday in Town'),
        body: t('外套與球鞋，是整套的基礎。', 'The jacket and sneakers carry the look.'),
        look: _cityWalk,
        pieces: [
          MagazineBreakdownPiece(label: 'Outer', item: jacket),
          MagazineBreakdownPiece(label: 'Shoes', item: sneakers),
          MagazineBreakdownPiece(label: 'Top', item: jacket),
          MagazineBreakdownPiece(item: sneakers),
        ],
      ),
    ],
  );
}

/// Brand Story, cover + four: a feature for the brand, its materials as a
/// detail without a main photo, an editor's note, and a selection without
/// the prompt (one item has no product to buy).
MagazineStory _brandStory(_Copy t) {
  const brand = 'KUMO ATELIER';
  return MagazineStory(
    summary: _summary(
      3,
      kicker: 'Brand Story',
      title: brand,
      subtitle: t(
        '從面料出發，重新定義日常服裝。',
        'Everyday clothes, starting from the fabric.',
      ),
      cover: _cityWalk,
    ),
    pages: [
      MagazineFeatureSlide(
        label: 'Brand Spotlight',
        heading: brand,
        info: 'Tokyo / Est. 2016',
        body: t(
          '自家開發布料，只做少量的日常基本款。',
          'Fabrics developed in-house, made into a few everyday basics.',
        ),
        photo: _trail,
      ),
      MagazineDetailSlide(
        label: 'The Materials',
        heading: t('三種自家布料', 'Three House Fabrics'),
        details: [
          _captioned(_jacket, t('羊毛', 'Wool'), t('日本尾州織造', 'Woven in Bishu')),
          _captioned(
            _sneakers,
            t('皮革', 'Leather'),
            t('植鞣，越用越軟', 'Veg-tanned, softens'),
          ),
          _captioned(
            _jacket,
            t('棉麻', 'Cotton-linen'),
            t('夏季限定', 'Summer only'),
          ),
        ],
      ),
      MagazineTypographySlide(
        label: 'Editorial Note',
        heading: t(
          '「好的衣服，應該成為生活的一部分。」',
          '“Good clothes should become part of your life.”',
        ),
        attribution: t('KUMO ATELIER 設計師', 'Designer, KUMO ATELIER'),
        tone: MagazineSlideTone.dark,
      ),
      MagazineSelectionSlide(
        label: 'Shop the Brand',
        heading: t('從這兩件開始', 'Start with These Two'),
        items: [
          _jacketItem(t, brand: brand),
          _sneakersItem(t, brand: brand),
        ],
      ),
    ],
  );
}
