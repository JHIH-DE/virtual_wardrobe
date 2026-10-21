import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/create_outfit_page.dart';
import 'package:uwearis/features/pages/outfit_edit_page.dart';
import 'package:uwearis/features/widgets/common/cards/app_list_card.dart';
import 'package:uwearis/features/widgets/common/cards/card_corner_badge.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/fake_auth.dart';
import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._items);
  final List<Garment> _items;

  @override
  Future<List<Garment>> build() async => _items;
}

Garment _garment(int id, GarmentCategory category, String name, String sub) =>
    Garment(
      id: id,
      garmentId: id,
      name: name,
      category: category,
      subCategory: sub,
      uploadUrl: '',
      objectName: '',
    );

List<Garment> _closet(Locale locale) => locale.languageCode == 'zh'
    ? [
        _garment(1, GarmentCategory.top, '超大版型復古水洗牛仔卡車外套式襯衫', '襯衫'),
        _garment(2, GarmentCategory.bottom, '高腰直筒寬褲', '長褲'),
        _garment(3, GarmentCategory.shoes, '白色帆布鞋', '運動鞋'),
      ]
    : [
        _garment(
          1,
          GarmentCategory.top,
          'Oversized Vintage Windbreaker Overshirt',
          'Overshirt',
        ),
        _garment(2, GarmentCategory.bottom, 'High-Rise Wide Trousers', 'Pants'),
        _garment(3, GarmentCategory.shoes, 'Canvas Sneakers', 'Sneakers'),
      ];

/// The garment row (its GestureDetector'd card) that shows [name].
Finder _rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Container)).last;

void _expectReadableRow(WidgetTester tester, String name) {
  final row = _rowOf(name);
  final nameText = find.text(name);
  expect(
    tester.getSize(row).height,
    greaterThanOrEqualTo(84 - 0.5),
    reason: 'rows keep their default height as a minimum',
  );
  expectWithin(tester, nameText, row);
  expectNoBrokenWords(tester, nameText);
  expect(renderedLineCount(tester, nameText), lessThanOrEqualTo(2));

  // The photo still spans the row (8px inset) at its fixed width.
  final image = find.descendant(of: row, matching: find.byType(GarmentImage));
  expect(
    tester.getSize(image).height,
    closeTo(tester.getSize(row).height - 16, 0.5),
  );

  // Every action badge stays fully inside the row with its 24x44 hit box.
  final badges = find.descendant(
    of: row,
    matching: find.byType(CardCornerBadge),
  );
  for (var i = 0; i < badges.evaluate().length; i++) {
    expectWithin(tester, badges.at(i), row);
    final size = tester.getSize(badges.at(i));
    expect(size.width, greaterThanOrEqualTo(24));
    expect(size.height, greaterThanOrEqualTo(AppDimens.minTouchTarget));
  }
}

/// A closet garment that isn't in the outfit, so Add Garment stays enabled
/// (with its arrow) instead of greying out as exhausted.
final _spare = _garment(4, GarmentCategory.accessory, 'Wool Scarf', 'Scarf');

void _expectAddGarmentRowReadable(WidgetTester tester, AppLocalizations l10n) {
  expect(
    find.descendant(
      of: find.byType(AppListCard),
      matching: find.byIcon(Icons.arrow_forward_ios_rounded),
    ),
    findsOneWidget,
    reason: 'Add Garment is enabled, arrow included',
  );
  final title = find.text(l10n.addGarment);
  expectWithin(tester, title, find.byType(AppListCard));
  expectNoBrokenWords(tester, title);
  expectNoBrokenWords(tester, find.text(l10n.browseYourClosetHint));
}

/// Writes a 100x300 PNG — a tall photo like a pair of trousers.
Future<String> _writeTallPhoto() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 100, 300),
    Paint()..color = const Color(0xFF222222),
  );
  final image = await recorder.endRecording().toImage(100, 300);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await Directory.systemTemp.createTemp('tall_photo');
  final file = File('${dir.path}/tall.png');
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file.path;
}

/// A loaded tall photo must not stretch its row past the text's height.
Future<void> _expectTallPhotoKeepsRowHeight(
  WidgetTester tester,
  Widget Function(Garment tall) page,
) async {
  final path = (await tester.runAsync(_writeTallPhoto))!;
  final tall = Garment(
    id: 9,
    garmentId: 9,
    name: 'Cargo Pants',
    category: GarmentCategory.bottom,
    subCategory: 'Pants',
    uploadUrl: '',
    objectName: '',
    imageUrl: path,
  );
  await pumpApp(
    tester,
    page(tall),
    overrides: [
      garmentsProvider.overrideWith(() => _FakeGarments([tall, _spare])),
    ],
  );
  await tester.pump();
  // File decoding runs off the fake clock.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  expect(tester.getSize(_rowOf('Cargo Pants')).height, closeTo(84, 0.5));
}

void main() {
  setUpAll(loadAppFont);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth();
  });

  group('Create Outfit', () {
    for (final c in layoutCases) {
      testWidgets('garment rows stay readable, locked and unlocked, at '
          '${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c, height: 3000);
        final closet = _closet(c.locale);
        await pumpApp(
          tester,
          CreateOutfitPage(initialGarments: closet),
          overrides: [
            garmentsProvider.overrideWith(
              () => _FakeGarments([...closet, _spare]),
            ),
          ],
        );
        await tester.pump();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CreateOutfitPage)),
        );

        _expectAddGarmentRowReadable(tester, l10n);
        final longName = closet.first.name;
        final row = _rowOf(longName);
        Finder lockIn(IconData icon) =>
            find.descendant(of: row, matching: find.byIcon(icon));
        final initiallyLocked = lockIn(Icons.lock).evaluate().isNotEmpty;

        for (final g in closet) {
          _expectReadableRow(tester, g.name);
        }

        // Toggle the long-named row's lock: the other state lays out too,
        // and the badge still works wherever the layout put it.
        await tester.tap(
          lockIn(initiallyLocked ? Icons.lock : Icons.lock_open),
        );
        await tester.pump();
        expect(
          lockIn(initiallyLocked ? Icons.lock_open : Icons.lock),
          findsOneWidget,
        );
        _expectReadableRow(tester, longName);

        // Remove still reaches its own row.
        await tester.tap(
          find.descendant(of: row, matching: find.byIcon(Icons.close)),
        );
        await tester.pump();
        expect(find.text(longName), findsNothing);
      });
    }
  });

  testWidgets('Create Outfit: a tall photo keeps the row at its text height', (
    tester,
  ) async {
    await _expectTallPhotoKeepsRowHeight(
      tester,
      (tall) => CreateOutfitPage(initialGarments: [tall]),
    );
  });

  testWidgets('Outfit Edit: a tall photo keeps the row at its text height', (
    tester,
  ) async {
    await _expectTallPhotoKeepsRowHeight(
      tester,
      (tall) => OutfitEditPage(
        preloadedGarments: [tall, _spare],
        initialGarments: [tall],
      ),
    );
  });

  group('Outfit Edit', () {
    for (final c in layoutCases) {
      testWidgets('garment rows stay readable at ${describeCase(c)}', (
        tester,
      ) async {
        applyLayoutCase(tester, c, height: 3000);
        final closet = _closet(c.locale);
        await pumpApp(
          tester,
          OutfitEditPage(
            preloadedGarments: [...closet, _spare],
            initialGarments: closet,
          ),
        );
        await tester.pump();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(OutfitEditPage)),
        );

        _expectAddGarmentRowReadable(tester, l10n);
        for (final g in closet) {
          _expectReadableRow(tester, g.name);
        }

        final longName = closet.first.name;
        await tester.tap(
          find.descendant(
            of: _rowOf(longName),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pump();
        expect(find.text(longName), findsNothing);
      });
    }
  });
}
