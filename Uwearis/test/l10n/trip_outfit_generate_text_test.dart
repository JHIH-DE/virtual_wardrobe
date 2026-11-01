import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/trip_outfit.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';
import 'package:uwearis/l10n/trip_outfit_generate_text.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  String message({
    int saved = 0,
    int ai = 0,
    int replaced = 0,
    TripOutfitAiStatus status = TripOutfitAiStatus.ok,
    TripOutfitGenerateMode mode = TripOutfitGenerateMode.more,
  }) => tripOutfitGenerateMessage(
    l10n,
    TripOutfitGenerateResult(
      collection: const TripOutfitCollection(),
      savedAddedCount: saved,
      aiAddedCount: ai,
      replacedCount: replaced,
      aiStatus: status,
    ),
    mode: mode,
  );

  test('names both sources when both added outfits', () {
    expect(message(saved: 4, ai: 3), 'Added 4 saved outfits and 3 AI outfits.');
    expect(message(saved: 1, ai: 1), 'Added 1 saved outfit and 1 AI outfit.');
  });

  test('saved only, AI only, nothing', () {
    expect(
      message(saved: 4, status: TripOutfitAiStatus.noNew),
      'Added 4 outfits from your saved looks.',
    );
    expect(message(ai: 2), 'Added 2 new AI outfits.');
    expect(
      message(status: TripOutfitAiStatus.skippedRecentEmpty),
      'No new outfit combinations found with your current suitcase.',
    );
  });

  test('saved kept after an AI failure or rate limit is a partial success', () {
    for (final status in [
      TripOutfitAiStatus.failed,
      TripOutfitAiStatus.rateLimited,
    ]) {
      expect(
        message(saved: 5, status: status),
        "Saved outfits were added, but AI styling couldn't be completed.",
      );
    }
  });

  test('refresh reports what it replaced', () {
    expect(
      message(ai: 3, replaced: 3, mode: TripOutfitGenerateMode.refresh),
      'Refreshed 3 AI outfits.',
    );
    expect(
      message(mode: TripOutfitGenerateMode.refresh),
      'No new outfit combinations found with your current suitcase.',
    );
  });
}
