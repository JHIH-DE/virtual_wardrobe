import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/editorial_typography.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis/features/widgets/common/adaptive_side_layout.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/magazine/magazine_item_card.dart';
import 'package:uwearis/features/widgets/magazine/magazine_network_photo.dart';
import 'package:uwearis/features/widgets/magazine/magazine_slide_view.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

/// The style an editorial text (rendered as a rich text) is set in.
TextStyle _styleOf(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).textSpan!.style!;

EditorialSurface _surfaceOf(MagazineSlideTone tone) =>
    tone == MagazineSlideTone.dark
    ? EditorialSurface.dark
    : EditorialSurface.page;

const _product = MagazineProduct(
  id: 20,
  brand: 'COMOLI',
  name: 'Track Jacket',
  price: 38000,
  currency: 'TWD',
  productUrl: 'https://shop/jacket',
  isAvailable: true,
);

const _items = [
  MagazineItem(id: 1, name: 'Wool Knit Track Jacket', product: _product),
  MagazineItem(id: 2, name: 'Silk Fleece Half-Zip', brand: 'A.PRESSE'),
  MagazineItem(id: 3, name: 'Hopsack Drawstring Pants', brand: 'Graphpaper'),
  MagazineItem(id: 4, name: 'Cashmere Sweatpants', brand: 'HERILL'),
];

/// Short names: the test font's glyphs are wide.
const _pieces = [
  MagazineBreakdownPiece(
    label: 'Outer',
    item: MagazineItem(id: 1, name: 'Knit'),
  ),
  MagazineBreakdownPiece(item: MagazineItem(id: 2, name: 'Pants')),
  MagazineBreakdownPiece(
    label: 'Shoes',
    item: MagazineItem(id: 3, name: 'Shoe'),
  ),
  MagazineBreakdownPiece(
    label: 'Bag',
    item: MagazineItem(id: 4, name: 'Tote'),
  ),
  MagazineBreakdownPiece(
    label: 'Top',
    item: MagazineItem(id: 5, name: 'Tee'),
  ),
  MagazineBreakdownPiece(
    label: 'Accessory',
    item: MagazineItem(id: 6, name: 'Cap'),
  ),
];

const _photoUrl = MagazinePhoto(url: 'https://x/photo.jpg');

/// Copy at the backend's limits (heading 60, body 200 characters), with
/// image titles and captions as long as a CMS editor would plausibly write.
({String heading, String body, String title, String caption}) _copyFor(
  Locale locale,
) => locale.languageCode == 'zh'
    ? (
        heading: '從網球場到辦公室' * 7,
        body: '把俱樂部運動服交給日本品牌重新打磨，用絲、羊毛與喀什米爾取代一般布料。' * 6,
        title: '升級材質',
        caption: '一樣的外型，換成絲與喀什米爾。',
      )
    : (
        heading: 'Sportswear made the way you would make a suit, quietly done',
        body:
            'Japanese labels keep the shape of the track jacket you know and '
            'put the effort into fabric, fit and finishing: silk fleece, wool '
            'knit and rare cashmere instead of polyester and nylon fabric.',
        title: 'Upgrade the Fabric',
        caption: 'The same shape in silk and cashmere.',
      );

List<MagazineCaptionedPhoto> _captioned(
  int count, {
  String? title,
  String? caption,
}) => [
  for (var i = 0; i < count; i++)
    MagazineCaptionedPhoto(photo: _photoUrl, title: title, caption: caption),
];

List<MagazineSwatch> _swatches({bool named = true}) => [
  for (final (i, name) in ['Brown', 'Sand', 'Cream'].indexed)
    MagazineSwatch(argb: 0xFF5B4A3A + i * 0x101010, name: named ? name : null),
];

/// Every layout in each of its arrangements.
List<MagazineSlide> _slides({
  String? label,
  String? heading,
  String? body,
  String? title,
  String? caption,
}) => [
  for (final position in MagazineSlideTextPosition.values)
    MagazineImmersiveSlide(
      label: label,
      heading: heading,
      body: body,
      textPosition: position,
    ),
  for (final position in MagazineSlideTextPosition.values)
    for (final ratio in MagazineImageRatio.values)
      MagazineFeatureSlide(
        label: label,
        heading: heading,
        body: body,
        info: title,
        caption: caption,
        photo: _photoUrl,
        imageRatio: ratio,
        textPosition: position,
      ),
  for (final main in [true, false])
    for (final details in [0, 1, 2, 3])
      for (final swatches in [true, false])
        if (details > 0 || swatches)
          MagazineDetailSlide(
            label: label,
            heading: heading,
            body: body,
            main: main
                ? MagazineCaptionedPhoto(photo: _photoUrl, caption: caption)
                : null,
            details: _captioned(details, title: title, caption: caption),
            swatches: swatches ? _swatches(named: title != null) : const [],
          ),
  for (final count in [2, 3, 4])
    for (final ratio in [
      MagazineImageRatio.portrait,
      MagazineImageRatio.square,
    ])
      MagazineGallerySlide(
        label: label,
        heading: heading,
        body: body,
        imageRatio: ratio,
        numbered: count == 3,
        images: _captioned(count, title: title, caption: caption),
      ),
  for (final count in [2, 3])
    MagazineListSlide(
      label: label,
      heading: heading,
      body: body,
      numbered: true,
      entries: _captioned(count, title: title, caption: caption),
    ),
  for (final count in [1, 3, 4, 6])
    MagazineBreakdownSlide(
      label: label,
      heading: heading,
      body: body,
      look: _photoUrl,
      pieces: _pieces.take(count).toList(),
    ),
  if (heading != null)
    for (final tone in MagazineSlideTone.values)
      for (final number in [null, '03'])
        MagazineTypographySlide(
          label: label,
          heading: heading,
          body: body,
          tone: tone,
          attribution: title,
          number: number,
        ),
  for (final prompt in [true, false])
    MagazineSelectionSlide(
      label: label,
      heading: heading,
      body: body,
      items: _items,
      wardrobePrompt: prompt,
    ),
];

/// The reader's chrome on top and a home indicator below.
const _chrome = EdgeInsets.only(top: 96, bottom: 34);

Future<void> _pump(WidgetTester tester, Widget slide) =>
    pumpApp(tester, Scaffold(body: slide));

void _phone(WidgetTester tester) =>
    applyLayoutCase(tester, (width: 390, scale: 1, locale: const Locale('en')));

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

List<Rect> _photos(WidgetTester tester) => [
  for (final e in find.byType(MagazineNetworkPhoto).evaluate())
    tester.getRect(find.byWidget(e.widget)),
];

void main() {
  testWidgets('every layout shows its label with the page number, heading '
      'and body', (tester) async {
    _phone(tester);
    for (final slide in _slides(
      label: 'The Details',
      heading: 'One idea',
      body: 'Short copy.',
    )) {
      await _pump(
        tester,
        MagazineSlideView(slide: slide, padding: _chrome, pageNumber: 3),
      );
      expect(find.text('THE DETAILS / 03'), findsOneWidget, reason: '$slide');
      expect(find.text('One idea'), findsOneWidget, reason: '$slide');
      expect(find.text('Short copy.'), findsOneWidget, reason: '$slide');
    }
  });

  testWidgets('every layout sets its label, heading and body in the shared '
      'roles, whatever room it has', (tester) async {
    for (final height in [844.0, 568.0]) {
      applyLayoutCase(tester, (
        width: 390,
        scale: 1,
        locale: const Locale('en'),
      ), height: height);
      for (final slide in _slides(
        label: 'The Details',
        heading: 'One idea',
        body: 'Short copy.',
      )) {
        await _pump(
          tester,
          MagazineSlideView(slide: slide, padding: _chrome, pageNumber: 3),
        );
        final (heading, body) = switch (slide) {
          MagazineImmersiveSlide() => (
            EditorialTypography.coverTitle.on(EditorialSurface.image),
            EditorialTypography.coverSubtitle.on(EditorialSurface.image),
          ),
          MagazineTypographySlide(:final tone) => (
            EditorialTypography.quote.on(_surfaceOf(tone)),
            EditorialTypography.body.on(_surfaceOf(tone)),
          ),
          _ => (EditorialTypography.pageHeading, EditorialTypography.body),
        };
        final label = EditorialTypography.sectionLabel.on(switch (slide) {
          MagazineImmersiveSlide() => EditorialSurface.image,
          MagazineTypographySlide(:final tone) => _surfaceOf(tone),
          _ => EditorialSurface.page,
        });
        expect(
          _styleOf(tester, find.text('THE DETAILS / 03')),
          label.style,
          reason: '$slide',
        );
        expect(
          _styleOf(tester, find.text('One idea')),
          heading.style,
          reason: '$slide',
        );
        expect(
          _styleOf(tester, find.text('Short copy.')),
          body.style,
          reason: '$slide',
        );
      }
    }
  });

  testWidgets('breakdown pieces and selection items share the product '
      'name', (tester) async {
    _phone(tester);
    final names = <TextStyle>[];
    for (final slide in _slides()) {
      final name = switch (slide) {
        MagazineBreakdownSlide() => 'Knit',
        MagazineSelectionSlide() => 'Wool Knit Track Jacket',
        _ => null,
      };
      if (name == null) continue;
      await _pump(tester, MagazineSlideView(slide: slide, padding: _chrome));
      names.add(_styleOf(tester, find.text(name)));
    }
    expect(names, hasLength(6));
    expect(names, everyElement(EditorialTypography.productName.style));
  });

  testWidgets('without optional copy a slide shows only its photos', (
    tester,
  ) async {
    _phone(tester);
    for (final slide in _slides().where(
      (s) =>
          s is! MagazineSelectionSlide &&
          s is! MagazineBreakdownSlide &&
          !(s is MagazineGallerySlide && s.numbered) &&
          s is! MagazineListSlide,
    )) {
      await _pump(tester, MagazineSlideView(slide: slide, padding: _chrome));
      expect(find.byType(Text), findsNothing, reason: '$slide');
    }
  });

  testWidgets('no photo is stretched, and none starts under the chrome', (
    tester,
  ) async {
    _phone(tester);
    for (final slide in _slides(label: 'L', heading: 'H', title: 'T')) {
      if (slide is MagazineImmersiveSlide) continue;
      await _pump(tester, MagazineSlideView(slide: slide, padding: _chrome));
      // Product cut-outs are shown whole (contain), so only cropped photos
      // count. A breakdown's look beside its pieces only loses its sides,
      // down to half as wide as tall; a gallery's people fill the screen,
      // down to 2:7.
      final tallest = switch (slide) {
        MagazineBreakdownSlide() => 2.0,
        MagazineGallerySlide(imageRatio: MagazineImageRatio.portrait) => 3.5,
        _ => 1.5,
      };
      for (final e in find.byType(MagazineNetworkPhoto).evaluate()) {
        if ((e.widget as MagazineNetworkPhoto).fit == BoxFit.contain) continue;
        final photo = tester.getRect(find.byWidget(e.widget));
        final ratio = photo.height / photo.width;
        expect(ratio, inInclusiveRange(0.59, tallest + 0.01), reason: '$slide');
        expect(photo.top, greaterThanOrEqualTo(_chrome.top), reason: '$slide');
      }
    }
  });

  testWidgets('feature: copy above the photo by default, below on request', (
    tester,
  ) async {
    _phone(tester);
    for (final position in MagazineSlideTextPosition.values) {
      await _pump(
        tester,
        MagazineSlideView(
          slide: MagazineFeatureSlide(
            heading: 'Heading',
            info: 'Tokyo / Est. 2016',
            caption: 'AW26',
            textPosition: position,
          ),
          padding: _chrome,
        ),
      );
      final heading = _rectOf(tester, find.text('Heading'));
      final photo = _rectOf(tester, find.byType(MagazineNetworkPhoto));
      if (position == MagazineSlideTextPosition.top) {
        expect(heading.bottom, lessThanOrEqualTo(photo.top));
      } else {
        expect(heading.top, greaterThanOrEqualTo(photo.bottom));
      }
      expect(find.text('Tokyo / Est. 2016'), findsOneWidget);
      expect(_rectOf(tester, find.text('AW26')).top, greaterThan(photo.bottom));
    }
  });

  testWidgets('feature: each image ratio keeps to its range', (tester) async {
    _phone(tester);
    for (final (ratio, min, max) in [
      (MagazineImageRatio.portrait, 5 / 4, 3 / 2),
      (MagazineImageRatio.square, 1.0, 1.0),
      (MagazineImageRatio.landscape, 3 / 5, 2 / 3),
    ]) {
      await _pump(
        tester,
        MagazineSlideView(
          slide: MagazineFeatureSlide(heading: 'H', imageRatio: ratio),
          padding: _chrome,
        ),
      );
      final photo = _photos(tester).single;
      expect(
        photo.height / photo.width,
        inInclusiveRange(min - 0.001, max + 0.001),
        reason: '$ratio',
      );
    }
  });

  testWidgets('detail: main photo, swatches, then close-ups side by side', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      MagazineSlideView(
        slide: MagazineDetailSlide(
          main: const MagazineCaptionedPhoto(photo: _photoUrl),
          details: _captioned(2, title: 'Suede'),
          swatches: _swatches(),
        ),
        padding: _chrome,
      ),
    );
    final photos = _photos(tester);
    expect(photos, hasLength(3));
    expect(photos[1].top, photos[2].top);
    expect(photos[1].top, greaterThan(photos[0].bottom + 40), reason: 'chips');
    expect(find.text('Brown · Sand · Cream'), findsOneWidget);
    expect(find.bySemanticsLabel('Brown'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('detail: without a main photo nothing is left in its place', (
    tester,
  ) async {
    _phone(tester);
    await _pump(
      tester,
      MagazineSlideView(
        slide: MagazineDetailSlide(
          heading: 'Fabrics',
          details: _captioned(3, title: 'Wool'),
        ),
        padding: _chrome,
      ),
    );
    final photos = _photos(tester);
    expect(photos, hasLength(3));
    expect(
      photos.first.top - _rectOf(tester, find.text('Fabrics')).bottom,
      lessThan(24),
    );
    // The first close-up leads; the other two share a row.
    expect(photos[1].top, photos[2].top);
    expect(photos[0].width, greaterThan(photos[1].width * 1.8));
  });

  testWidgets('gallery: two side by side, three as a lead over two, four '
      'two by two; never three in a row', (tester) async {
    _phone(tester);
    for (final count in [2, 3, 4]) {
      await _pump(
        tester,
        MagazineSlideView(
          slide: MagazineGallerySlide(images: _captioned(count, title: 'Look')),
          padding: _chrome,
        ),
      );
      final photos = _photos(tester);
      final rows = <double, int>{};
      for (final photo in photos) {
        rows.update(photo.top, (n) => n + 1, ifAbsent: () => 1);
      }
      expect(rows.values.every((n) => n <= 2), isTrue, reason: '$count');
      expect(rows.values.toList(), switch (count) {
        2 => [2],
        3 => [1, 2],
        _ => [2, 2],
      });
    }
  });

  testWidgets('gallery: numbered titles', (tester) async {
    _phone(tester);
    await _pump(
      tester,
      MagazineSlideView(
        slide: MagazineGallerySlide(
          numbered: true,
          images: [
            for (final title in ['Casual', null])
              MagazineCaptionedPhoto(photo: _photoUrl, title: title),
          ],
        ),
      ),
    );
    expect(find.text('1. Casual'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('gallery: becomes a list when a caption word won\'t fit', (
    tester,
  ) async {
    applyLayoutCase(tester, (width: 320, scale: 2, locale: const Locale('en')));
    await _pump(
      tester,
      MagazineSlideView(
        slide: MagazineGallerySlide(
          images: _captioned(4, title: 'Understated'),
        ),
      ),
    );
    expect(find.byType(AdaptiveSideLayout), findsNWidgets(4));
  });

  testWidgets('illustrated list: a photo beside each entry, numbered, '
      'divided', (tester) async {
    _phone(tester);
    await _pump(
      tester,
      MagazineSlideView(
        slide: MagazineListSlide(
          numbered: true,
          entries: _captioned(3, title: 'Tip', caption: 'Note'),
        ),
        padding: _chrome,
      ),
    );
    expect(find.byType(AdaptiveSideLayout), findsNWidgets(3));
    expect(find.byType(AppDivider), findsNWidgets(2));
    expect(find.text('01'), findsOneWidget);
    expect(find.text('03'), findsOneWidget);
    final photo = _photos(tester).first;
    expect(
      _rectOf(tester, find.text('Tip').first).left,
      greaterThan(photo.right),
    );
  });

  testWidgets('illustrated list of two: photos alternate sides, divided, '
      'numbered', (tester) async {
    _phone(tester);
    await _pump(
      tester,
      MagazineSlideView(
        slide: MagazineListSlide(
          entries: _captioned(2, title: 'Tip', caption: 'Note'),
        ),
        padding: _chrome,
      ),
    );
    expect(find.byType(AppDivider), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    final photos = _photos(tester);
    final titles = find.text('Tip');
    expect(_rectOf(tester, titles.at(0)).left, greaterThan(photos[0].right));
    expect(_rectOf(tester, titles.at(1)).right, lessThan(photos[1].left));
    expect(photos[0].height / photos[0].width, closeTo(3 / 2, 0.01));
    expect(photos[1].bottom, lessThanOrEqualTo(844 - 34));
  });

  testWidgets('breakdown: up to three pieces beside the look, shown whole', (
    tester,
  ) async {
    _phone(tester);
    MagazinePhoto? matched;
    await _pump(
      tester,
      MagazineSlideView(
        slide: MagazineBreakdownSlide(
          look: _photoUrl,
          pieces: _pieces.take(3).toList(),
        ),
        padding: _chrome,
        onMatchWardrobe: (photo) => matched = photo,
      ),
    );
    final photos = _photos(tester);
    final look = photos.first;
    expect(look.width / (390 - 48 - 12), closeTo(0.58, 0.01));
    for (final piece in photos.skip(1)) {
      expect(piece.left, greaterThan(look.right));
    }
    expect(find.byType(MagazineProductPhoto), findsNWidgets(3));
    for (final e in find.byType(MagazineNetworkPhoto).evaluate().skip(1)) {
      expect((e.widget as MagazineNetworkPhoto).fit, BoxFit.contain);
    }
    // The role in section-label type, the item's name under it.
    expect(find.text('OUTER'), findsOneWidget);
    expect(find.text('Knit'), findsOneWidget);
    expect(find.text('Pants'), findsOneWidget);

    await tester.ensureVisible(find.text('Match Your Wardrobe'));
    await tester.tap(find.text('Match Your Wardrobe'));
    expect(matched, same(_photoUrl));
  });

  group('breakdown grid', () {
    // Column counts follow real text widths.
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await loadAppFont();
      await loadEditorialFont();
    });

    testWidgets('breakdown: four pieces go two to a row under the look, five '
        'or six three to a row', (tester) async {
      _phone(tester);
      for (final (count, rowCount) in [(4, 2), (5, 2), (6, 2)]) {
        await _pump(
          tester,
          MagazineSlideView(
            slide: MagazineBreakdownSlide(
              look: _photoUrl,
              pieces: _pieces.take(count).toList(),
            ),
            padding: _chrome,
          ),
        );
        final photos = _photos(tester);
        final pieces = photos.skip(1).toList();
        expect(pieces, hasLength(count));
        expect(pieces.first.top, greaterThan(photos.first.bottom));
        final rows = <double>{for (final p in pieces) p.top};
        expect(rows, hasLength(rowCount), reason: '$count pieces');
        for (final piece in pieces) {
          expect(piece.height, lessThanOrEqualTo(piece.width + 0.01));
        }
        expect(find.byType(MagazineProductPhoto), findsNWidgets(count));
        expect(
          find.text('Match Your Wardrobe'),
          findsNothing,
          reason: 'unwired',
        );
      }
      expect(find.text('ACCESSORY'), findsOneWidget);
    });

    testWidgets('breakdown: at a large text size the grid drops to two '
        'across rather than breaking names after a character or two', (
      tester,
    ) async {
      applyLayoutCase(tester, (
        width: 390,
        scale: 2,
        locale: const Locale('zh', 'TW'),
      ));
      await _pump(
        tester,
        MagazineSlideView(
          slide: MagazineBreakdownSlide(look: _photoUrl, pieces: _pieces),
          padding: _chrome,
        ),
      );
      final pieces = _photos(tester).skip(1).toList();
      expect({for (final p in pieces) p.top}, hasLength(3));
    });
  });

  testWidgets('typography: chapter number, attribution and rule from the '
      'data; either tone', (tester) async {
    _phone(tester);
    Future<void> pump({
      String? number,
      String? attribution,
      bool dark = false,
    }) => _pump(
      tester,
      MagazineSlideView(
        slide: MagazineTypographySlide(
          heading: 'Less, but better.',
          body: 'Quiet quality.',
          number: number,
          attribution: attribution,
          tone: dark ? MagazineSlideTone.dark : MagazineSlideTone.light,
        ),
        padding: _chrome,
      ),
    );

    await pump();
    expect(find.byType(Divider), findsOneWidget);
    expect(
      _styleOf(tester, find.text('Less, but better.')).color,
      AppColors.textPrimary,
    );
    expect(find.byType(MagazineNetworkPhoto), findsNothing);
    final centre = _rectOf(tester, find.text('Less, but better.')).center.dy;
    expect(centre, inExclusiveRange(844 / 4, 844 / 2));

    await pump(attribution: 'Editorial Note', dark: true);
    expect(find.text('— Editorial Note'), findsOneWidget);
    expect(
      _styleOf(tester, find.text('Less, but better.')).color,
      AppColors.textOnPrimary,
    );

    await pump(number: '03');
    expect(find.text('03'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
    expect(
      _rectOf(tester, find.text('03')).bottom,
      lessThan(_rectOf(tester, find.text('Less, but better.')).top),
    );
  });

  testWidgets('selection: only a buyable item can be bought', (tester) async {
    _phone(tester);
    MagazineItem? shopped;
    await _pump(
      tester,
      MagazineSlideView(
        slide: const MagazineSelectionSlide(items: _items),
        padding: _chrome,
        onShopItem: (item) => shopped = item,
      ),
    );
    expect(find.byType(MagazineItemCard), findsNWidgets(4));
    for (final card in tester.widgetList<MagazineItemCard>(
      find.byType(MagazineItemCard),
    )) {
      expect(card.variant, MagazineItemCardVariant.editorial);
    }
    expect(find.text('Shop'), findsOneWidget);
    expect(
      tester.widget<AccentPillButton>(find.byType(AccentPillButton)).variant,
      AccentPillButtonVariant.editorial,
    );
    await tester.ensureVisible(find.text('Shop'));
    await tester.tap(find.text('Shop'));
    expect(shopped?.id, 1);
  });

  testWidgets('selection: no shop action without a handler (CMS preview)', (
    tester,
  ) async {
    _phone(tester);
    await _pump(
      tester,
      const MagazineSlideView(slide: MagazineSelectionSlide(items: _items)),
    );
    expect(find.text('Shop'), findsNothing);
  });

  testWidgets('selection: the wardrobe prompt when the page asks for it; its '
      'button only when wired', (tester) async {
    _phone(tester);
    const cover = MagazinePhoto(url: 'https://x/cover.jpg');
    await _pump(
      tester,
      const MagazineSlideView(
        slide: MagazineSelectionSlide(items: _items),
        storyCover: cover,
      ),
    );
    expect(find.text('Make It Yours'), findsNothing);

    await _pump(
      tester,
      const MagazineSlideView(
        slide: MagazineSelectionSlide(items: _items, wardrobePrompt: true),
        storyCover: cover,
      ),
    );
    expect(find.text('Make It Yours'), findsOneWidget);
    expect(find.text('Match Your Wardrobe'), findsNothing);

    MagazinePhoto? matched;
    await _pump(
      tester,
      MagazineSlideView(
        slide: const MagazineSelectionSlide(
          items: _items,
          wardrobePrompt: true,
        ),
        storyCover: cover,
        onMatchWardrobe: (look) => matched = look,
      ),
    );
    await tester.ensureVisible(find.text('Match Your Wardrobe'));
    await tester.tap(find.text('Match Your Wardrobe'));
    expect(matched, same(cover));
  });

  testWidgets('cover shows kicker in capitals, title and subtitle', (
    tester,
  ) async {
    _phone(tester);
    await _pump(
      tester,
      const MagazineCoverSlideView(
        summary: MagazineStorySummary(
          id: 1,
          issueId: 1,
          slug: 's',
          format: MagazineFormat.story,
          kicker: 'Style Notes',
          title: 'Old Money Sport',
          subtitle: 'The silhouette of sportswear.',
        ),
        padding: _chrome,
        pageNumber: 1,
      ),
    );
    expect(find.text('STYLE NOTES / 01'), findsOneWidget);
    expect(find.text('Old Money Sport'), findsOneWidget);
    expect(find.text('The silhouette of sportswear.'), findsOneWidget);
  });

  testWidgets('immersive: the gradient covers the copy, not the photo', (
    tester,
  ) async {
    _phone(tester);
    await _pump(
      tester,
      const MagazineSlideView(
        slide: MagazineImmersiveSlide(heading: 'Heading', photo: _photoUrl),
        padding: _chrome,
      ),
    );
    final gradient = _rectOf(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            (w.decoration as BoxDecoration?)?.gradient != null,
      ),
    );
    expect(gradient.height, lessThan(844 / 2));
    expect(gradient.bottom, 844);
  });

  // A photo keeps the ratio its layout prefers when the screen has room for
  // it, cropping a little only on a short screen, and never grows past it to
  // fill the page.
  testWidgets('a gallery of people sets its captions over the photos, one of '
      'details under them', (tester) async {
    _phone(tester);
    for (final ratio in MagazineImageRatio.values.where(
      (r) => r != MagazineImageRatio.landscape,
    )) {
      await _pump(
        tester,
        MagazineSlideView(
          slide: MagazineGallerySlide(
            imageRatio: ratio,
            images: _captioned(2, title: 'Look', caption: 'Note'),
          ),
          padding: _chrome,
        ),
      );
      final photo = _photos(tester).first;
      final title = _rectOf(tester, find.text('Look').first);
      if (ratio == MagazineImageRatio.portrait) {
        expect(photo.contains(title.center), isTrue, reason: '$ratio');
        expect(title.bottom, lessThan(photo.bottom));
      } else {
        expect(title.top, greaterThan(photo.bottom), reason: '$ratio');
      }
    }
  });

  testWidgets('a gallery fills the screen, up to 2:7 for people and 2:3 for '
      'details', (tester) async {
    for (final (height, ratio) in [
      (844.0, MagazineImageRatio.portrait),
      (568.0, MagazineImageRatio.portrait),
      (844.0, MagazineImageRatio.square),
    ]) {
      applyLayoutCase(tester, (
        width: 390,
        scale: 1,
        locale: const Locale('en'),
      ), height: height);
      await _pump(
        tester,
        MagazineSlideView(
          slide: MagazineGallerySlide(
            heading: 'Looks',
            imageRatio: ratio,
            images: _captioned(2, title: 'Look'),
          ),
          padding: _chrome,
        ),
      );
      final photo = _photos(tester).first;
      final shape = photo.height / photo.width;
      final reason = '$ratio ${height}pt';
      if (height == 568) {
        expect(photo.bottom, closeTo(height - _chrome.bottom - 24, 1));
        expect(shape, lessThan(3.5), reason: reason);
      } else {
        expect(
          shape,
          closeTo(ratio == MagazineImageRatio.portrait ? 3.5 : 1.5, 0.001),
          reason: reason,
        );
      }
    }
  });

  group('cover title', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await loadAppFont();
      await loadEditorialFont();
    });

    double titleSize(WidgetTester tester) =>
        _styleOf(tester, find.text('Sportswear Tailored')).fontSize!;

    Future<void> pumpCover(WidgetTester tester, LayoutCase c) {
      applyLayoutCase(tester, c);
      return _pump(
        tester,
        const MagazineCoverSlideView(
          summary: MagazineStorySummary(
            id: 1,
            issueId: 1,
            slug: 's',
            title: 'Sportswear Tailored',
          ),
        ),
      );
    }

    testWidgets('keeps the headline size while its words fit', (tester) async {
      await pumpCover(tester, (
        width: 390,
        scale: 1,
        locale: const Locale('en'),
      ));
      expect(titleSize(tester), 34);
    });

    testWidgets('shrinks, not below its minimum, for a long word', (
      tester,
    ) async {
      await pumpCover(tester, (
        width: 320,
        scale: 2,
        locale: const Locale('en'),
      ));
      expect(titleSize(tester), lessThan(34));
      expect(
        titleSize(tester),
        greaterThanOrEqualTo(EditorialTypography.coverTitle.minFontSize!),
      );
      expectNoBrokenWords(tester, find.text('Sportswear Tailored'));
    });
  });

  group('layout', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await loadAppFont();
      await loadEditorialFont();
    });

    // 844 = a current iPhone, 568 = iPhone SE (1st gen), the shortest.
    for (final height in [844.0, 568.0]) {
      for (final c in layoutCases) {
        testWidgets('${describeCase(c)} · ${height.toInt()}pt tall', (
          tester,
        ) async {
          applyLayoutCase(tester, c, height: height);
          final copy = _copyFor(c.locale);
          final slides = [
            MagazineCoverSlideView(
              summary: MagazineStorySummary(
                id: 1,
                issueId: 1,
                slug: 's',
                kicker: 'STYLE NOTES',
                title: copy.heading,
                subtitle: copy.body,
              ),
              padding: _chrome,
            ),
            for (final slide in _slides(
              label: 'The Silhouette',
              heading: copy.heading,
              body: copy.body,
              title: copy.title,
              caption: copy.caption,
            ))
              MagazineSlideView(
                slide: slide,
                padding: _chrome,
                pageNumber: 2,
                storyCover: const MagazinePhoto(url: 'https://x/c.jpg'),
                onMatchWardrobe: (_) {},
              ),
          ];
          for (final slide in slides) {
            // Overflow fails the test on its own; text may scroll inside its
            // box, but the box stays on screen and no Latin word splits.
            await _pump(tester, slide);
            for (final text in find.byType(Text).evaluate()) {
              expectNoBrokenWords(tester, find.byWidget(text.widget));
            }
            for (final scroll
                in find.byType(SingleChildScrollView).evaluate()) {
              expectWithin(
                tester,
                find.byWidget(scroll.widget),
                find.byType(Scaffold),
              );
            }
          }
        });
      }
    }
  });

  testWidgets('a zoomed photo is enlarged around its focal point, inside '
      'its frame; a cut-out never is', (tester) async {
    _phone(tester);
    await _pump(
      tester,
      const SizedBox(
        width: 200,
        height: 300,
        child: MagazineNetworkPhoto(
          photo: MagazinePhoto(
            url: 'https://x/a.jpg',
            focalX: 0.5,
            focalY: -0.5,
            zoom: 1.5,
          ),
        ),
      ),
    );
    final scale = tester.widget<Transform>(
      find.descendant(
        of: find.byType(MagazineNetworkPhoto),
        matching: find.byType(Transform),
      ),
    );
    expect(scale.transform.getMaxScaleOnAxis(), 1.5);
    expect(scale.alignment, const Alignment(0.5, -0.5));
    expect(
      find.descendant(
        of: find.byType(MagazineNetworkPhoto),
        matching: find.byType(ClipRect),
      ),
      findsOneWidget,
    );

    await _pump(
      tester,
      const MagazineNetworkPhoto(
        photo: MagazinePhoto(url: 'https://x/a.jpg', zoom: 1.5),
        fit: BoxFit.contain,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(MagazineNetworkPhoto),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });

  testWidgets('a whole photo sits over a blurred copy of itself; a filling '
      'one has no backdrop', (tester) async {
    _phone(tester);
    Finder inPhoto(Finder f) =>
        find.descendant(of: find.byType(MagazineNetworkPhoto), matching: f);
    await _pump(
      tester,
      const SizedBox(
        width: 300,
        height: 400,
        child: MagazineNetworkPhoto(
          photo: MagazinePhoto(url: 'https://x/a.jpg', whole: true),
        ),
      ),
    );
    expect(inPhoto(find.byType(ImageFiltered)), findsOneWidget);
    expect(inPhoto(find.byType(Stack)), findsOneWidget);

    await _pump(
      tester,
      const SizedBox(
        width: 300,
        height: 400,
        child: MagazineNetworkPhoto(
          photo: MagazinePhoto(url: 'https://x/a.jpg'),
        ),
      ),
    );
    expect(inPhoto(find.byType(ImageFiltered)), findsNothing);
  });
}
