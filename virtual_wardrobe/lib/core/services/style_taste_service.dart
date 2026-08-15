import '../../data/style_taste.dart';

/// Mock/local stand-in for a future Style Taste backend — no such endpoint
/// exists yet. Shaped the way a real `BaseService` (HTTP + auth)
/// implementation would be, so swapping this out later is a one-file change
/// with no caller edits.
class StyleTasteService {
  // AI-generated advice copy (like Outfit.advice elsewhere in this app)
  // isn't routed through the app's ARB localization — it's opaque text a
  // real backend would already produce in the user's language.
  static const Map<StyleTasteDimension, String> _descriptions = {
    StyleTasteDimension.styleBalance:
        'You tend to like mixing pieces from different styles.',
    StyleTasteDimension.colorPairing:
        'You prefer soft, tonal color combinations.',
    StyleTasteDimension.fitPreference:
        'You usually go for relaxed and comfortable fits.',
    StyleTasteDimension.layering: 'You enjoy light layering.',
    StyleTasteDimension.accessories: 'You prefer minimal accessories.',
  };

  Future<List<StyleTastePreference>> getPreferences() async {
    var seed = 0;
    return StyleTasteDimension.values.map((dimension) {
      seed++;
      // Small per-dimension variation around the midpoint, purely so the
      // mock page doesn't render five identical bars before any answers.
      final score = (0.5 + ((seed % 3) - 1) * 0.12).clamp(0.0, 1.0);
      return StyleTastePreference(
        dimension: dimension,
        score: score,
        description: _descriptions[dimension],
      );
    }).toList();
  }

  /// One-paragraph AI read on the user's overall style personality, shown in
  /// the Style Taste page's insight card. Same "opaque AI copy, not routed
  /// through ARB" treatment as [_descriptions].
  Future<String> getPersonalitySummary() async {
    return 'You lean toward a relaxed, easy-to-wear base and let accessories '
        'do the talking rather than bold color contrasts — comfortable '
        'first, with personality layered on top.';
  }
}
