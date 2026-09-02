import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/style_taste.dart';

void main() {
  group('StyleTasteDimension', () {
    test('apiValue round-trips through styleTasteDimensionFromApiValue', () {
      for (final dimension in StyleTasteDimension.values) {
        expect(
          styleTasteDimensionFromApiValue(dimension.apiValue),
          dimension,
        );
      }
    });

    test('multi-word dimensions map to snake_case wire values', () {
      expect(StyleTasteDimension.styleBalance.apiValue, 'style_balance');
      expect(StyleTasteDimension.colorPairing.apiValue, 'color_pairing');
      expect(StyleTasteDimension.fitPreference.apiValue, 'fit_preference');
    });

    test('styleTasteDimensionFromApiValue returns null for an unknown value', () {
      expect(styleTasteDimensionFromApiValue('mystery'), isNull);
    });
  });

  group('StyleTastePreference', () {
    test('fromJson parses a full payload', () {
      final pref = StyleTastePreference.fromJson({
        'dimension': 'layering',
        'score': 0.8,
        'confidence': 0.6,
        'description': 'You like to layer.',
      });

      expect(pref.dimension, StyleTasteDimension.layering);
      expect(pref.score, 0.8);
      expect(pref.confidence, 0.6);
      expect(pref.description, 'You like to layer.');
    });

    test('falls back to styleBalance for an unrecognized/missing dimension', () {
      final pref = StyleTastePreference.fromJson({'score': 0.5});
      expect(pref.dimension, StyleTasteDimension.styleBalance);
    });

    test('defaults score to 0.5 and confidence to 1.0 when missing', () {
      final pref = StyleTastePreference.fromJson({'dimension': 'layering'});
      expect(pref.score, 0.5);
      expect(pref.confidence, 1.0);
      expect(pref.description, isNull);
    });

    test('toJson round-trips through fromJson', () {
      const pref = StyleTastePreference(
        dimension: StyleTasteDimension.accessories,
        score: 0.3,
        confidence: 0.9,
        description: 'Minimal accessories.',
      );
      final roundTripped = StyleTastePreference.fromJson(pref.toJson());

      expect(roundTripped.dimension, pref.dimension);
      expect(roundTripped.score, pref.score);
      expect(roundTripped.confidence, pref.confidence);
      expect(roundTripped.description, pref.description);
    });

    test('copyWith overrides only the given fields', () {
      const pref = StyleTastePreference(
        dimension: StyleTasteDimension.fitPreference,
        score: 0.4,
      );
      final updated = pref.copyWith(score: 0.9);
      expect(updated.score, 0.9);
      expect(updated.dimension, pref.dimension);
    });
  });

  group('StyleTasteProfile.fromApi', () {
    test('parses a keyed-by-dimension payload', () {
      final profile = StyleTasteProfile.fromApi({
        'status': 'ready',
        'summary': 'You lean minimal.',
        'style_balance': {'score': 0.2, 'confidence': 0.8, 'insight': 'Consistent.'},
        'color_pairing': {'score': 0.6, 'confidence': 0.5, 'insight': 'Balanced.'},
      });

      expect(profile.status, 'ready');
      expect(profile.summary, 'You lean minimal.');
      expect(profile.preferences, hasLength(2));
      final styleBalance = profile.preferences.firstWhere(
        (p) => p.dimension == StyleTasteDimension.styleBalance,
      );
      expect(styleBalance.score, 0.2);
      expect(styleBalance.description, 'Consistent.');
    });

    test('skips dimensions the response omits, rather than defaulting them in', () {
      final profile = StyleTasteProfile.fromApi({
        'status': 'learning',
        'summary': '',
        'layering': {'score': 0.5},
      });

      expect(profile.preferences, hasLength(1));
      expect(profile.preferences.single.dimension, StyleTasteDimension.layering);
    });

    test('ignores a non-map value under a dimension key instead of throwing', () {
      final profile = StyleTasteProfile.fromApi({
        'status': 'learning',
        'summary': '',
        'accessories': 'not-an-object',
      });
      expect(profile.preferences, isEmpty);
    });

    test('defaults status/summary when missing', () {
      final profile = StyleTasteProfile.fromApi({});
      expect(profile.status, 'learning');
      expect(profile.summary, '');
      expect(profile.preferences, isEmpty);
    });
  });
}
