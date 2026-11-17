import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/style_type.dart';
import 'package:uwearis/features/widgets/outfit/outfit_title.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh', 'TW'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('outfitTagLabel', () {
    test('translates seasons and styles, whatever their spelling', () {
      expect(outfitTagLabel(zh, 'summer'), '夏天');
      expect(outfitTagLabel(zh, 'Autumn'), '秋天');
      expect(outfitTagLabel(zh, 'smart_casual'), '質感休閒');
      expect(outfitTagLabel(zh, 'Smart Casual'), '質感休閒');
      expect(outfitTagLabel(en, 'smart_casual'), 'Smart Casual');
    });

    test('Minimal uses the short tag label', () {
      expect(outfitTagLabel(zh, 'minimal'), '極簡');
      expect(outfitTagLabel(en, 'minimal'), 'Minimal');
    });

    test('an unknown tag is title-cased', () {
      expect(outfitTagLabel(zh, 'rainy_day'), 'Rainy Day');
    });
  });

  group('outfitDisplayTitle', () {
    test('builds the title from the first tag, translated', () {
      expect(
        outfitDisplayTitle(zh, seasons: const ['summer'], style: const []),
        '夏天穿搭',
      );
      expect(
        outfitDisplayTitle(
          en,
          seasons: const [],
          style: const ['smart_casual'],
        ),
        'Smart Casual Outfit',
      );
    });

    test('a name wins; no tags falls back to My Outfit', () {
      expect(
        outfitDisplayTitle(
          zh,
          name: 'Date night',
          seasons: const ['summer'],
          style: const [],
        ),
        'Date night',
      );
      expect(
        outfitDisplayTitle(en, seasons: const [''], style: const []),
        en.myOutfit,
      );
    });
  });

  test('normalizeOutfitTag maps older spellings onto the catalog', () {
    expect(normalizeOutfitTag('Smart Casual'), 'smart_casual');
    expect(normalizeOutfitTag('STREET_WEAR'), 'streetwear');
    expect(normalizeOutfitTag(' Summer '), 'summer');
    expect(normalizeOutfitTag('Rainy Day'), 'rainy_day');
  });
}
