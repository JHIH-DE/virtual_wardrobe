import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// What editorial text sits on; it decides the text's colour.
enum EditorialSurface {
  /// The cream page.
  page,

  /// A photo, under a scrim.
  image,

  /// A dark typography page.
  dark,
}

/// One editorial text role. [style] sets Latin letters, digits and
/// punctuation; [cjk], merged over it, sets each run of Chinese (or other
/// CJK) characters, so a mixed line switches face per run rather than per
/// paragraph. Render it with `EditorialText`, which measures the same spans.
@immutable
class EditorialTextStyle {
  final TextStyle style;
  final TextStyle? cjk;

  /// Secondary text keeps a softer colour on the page and on a dark page;
  /// on a photo every role is white.
  final bool secondary;

  /// A display role may shrink to this size for a Latin word too wide for
  /// its line; null never shrinks.
  final double? minFontSize;

  const EditorialTextStyle(
    this.style, {
    this.cjk,
    this.secondary = false,
    this.minFontSize,
  });

  /// This role on [surface].
  EditorialTextStyle on(EditorialSurface surface) => merge(
    TextStyle(
      color: switch (surface) {
        EditorialSurface.page =>
          secondary ? AppColors.textSecondary : AppColors.textPrimary,
        EditorialSurface.image => AppColors.textOnPrimary,
        EditorialSurface.dark =>
          secondary ? AppColors.onPhotoMuted : AppColors.textOnPrimary,
      },
    ),
  );

  EditorialTextStyle merge(TextStyle other) => EditorialTextStyle(
    style.merge(other),
    cjk: cjk,
    secondary: secondary,
    minFontSize: minFontSize,
  );

  /// [text] as spans: CJK runs in [cjk] when it is set.
  TextSpan span(String text) {
    final cjk = this.cjk;
    if (cjk == null || !_cjkRun.hasMatch(text)) {
      return TextSpan(text: text, style: style);
    }
    final children = <TextSpan>[];
    var start = 0;
    for (final match in _cjkRun.allMatches(text)) {
      if (match.start > start) {
        children.add(TextSpan(text: text.substring(start, match.start)));
      }
      children.add(TextSpan(text: match[0], style: cjk));
      start = match.end;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }
    return TextSpan(style: style, children: children);
  }

  /// CJK ideographs, kana, CJK and full-width punctuation.
  static final RegExp _cjkRun = RegExp(r'[⺀-鿿豈-﫿︰-﹏＀-￯]+');
}

/// Editorial Stories' type (the story reader and its slides, their product
/// cards, credits and calls to action). Two faces: the editorial serif
/// (Newsreader) for Latin display text — cover titles, quotes, numbers — and
/// NotoSansTC for everything else, and for every CJK run, display roles
/// included. Every role sets its own line height (the box is then the same
/// for both faces on a mixed line), and tracking only where it helps: a
/// Latin label is spaced wide, a Chinese one barely.
///
/// One role, one style: layouts don't resize text to fill space. Only
/// [coverTitle] and [quote] may shrink, down to their `minFontSize`, for a
/// Latin word too wide for the line at a large text size.
abstract final class EditorialTypography {
  static TextStyle _sans(
    double size,
    FontWeight weight, {
    required double height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    leadingDistribution: TextLeadingDistribution.even,
    height: height,
    letterSpacing: letterSpacing,
    color: AppColors.textPrimary,
  );

  static final Locale _traditionalChinese = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'TW',
  );

  /// [style] on the page: secondary roles in the secondary colour.
  static EditorialTextStyle _role(
    TextStyle style, {
    TextStyle? cjk,
    bool secondary = false,
    double? minFontSize,
  }) => EditorialTextStyle(
    style,
    cjk: cjk,
    secondary: secondary,
    minFontSize: minFontSize,
  ).on(EditorialSurface.page);

  /// A display role's CJK runs: NotoSansTC at [weight], untracked.
  static TextStyle _cjkDisplay(FontWeight weight) => TextStyle(
    fontFamily: 'NotoSansTC',
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    letterSpacing: 0,
    locale: _traditionalChinese,
  );

  /// A story's title on its cover, and an Immersive page's heading.
  static final EditorialTextStyle coverTitle = _role(
    AppTextStyle.editorialSerif(
      34,
      FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.4,
    ),
    cjk: _cjkDisplay(FontWeight.w600),
    minFontSize: 26,
  );

  /// The line under a cover title.
  static final EditorialTextStyle coverSubtitle = _role(
    _sans(16, FontWeight.w400, height: 1.5),
    secondary: true,
  );

  /// A page's heading.
  static final EditorialTextStyle pageHeading = _role(
    _sans(24, FontWeight.w600, height: 1.3, letterSpacing: -0.2),
    cjk: const TextStyle(letterSpacing: 0),
  );

  /// "THE DETAILS / 03"; also a piece's role and a credit's heading.
  static final EditorialTextStyle sectionLabel = _role(
    _sans(12, FontWeight.w600, height: 1.35, letterSpacing: 1.4),
    cjk: const TextStyle(letterSpacing: 0.6),
    secondary: true,
  );

  /// A quiet line under a heading: who said a quote.
  static final EditorialTextStyle subtitle = _role(
    _sans(16, FontWeight.w400, height: 1.5),
    secondary: true,
  );

  /// A photo's or list entry's title.
  static final EditorialTextStyle itemTitle = _role(
    _sans(16, FontWeight.w600, height: 1.35),
  );

  static final EditorialTextStyle body = _role(
    _sans(16, FontWeight.w400, height: 1.55),
  );

  /// Under or over a photo, a list entry's note, a swatch's name, a credit.
  static final EditorialTextStyle caption = _role(
    _sans(13, FontWeight.w400, height: 1.45),
    secondary: true,
  );

  static final EditorialTextStyle productName = _role(
    _sans(14, FontWeight.w500, height: 1.4),
  );

  /// A product's brand and price; a brand's facts under its name.
  static final EditorialTextStyle productMeta = _role(
    _sans(12, FontWeight.w400, height: 1.4, letterSpacing: 0.2),
    cjk: const TextStyle(letterSpacing: 0),
    secondary: true,
  );

  /// A list entry's "01".
  static final EditorialTextStyle editorialNumber = _role(
    AppTextStyle.editorialSerif(
      36,
      FontWeight.w400,
      height: 1,
      letterSpacing: -0.5,
    ),
    secondary: true,
  );

  /// A typography page's words, in the serif's Regular; its CJK runs at
  /// the same weight, which already reads as heavy as the serif's strokes.
  static final EditorialTextStyle quote = _role(
    AppTextStyle.editorialSerif(
      30,
      FontWeight.w400,
      height: 1.3,
      letterSpacing: -0.3,
    ),
    cjk: _cjkDisplay(FontWeight.w400),
    minFontSize: 24,
  );

  /// A chapter's number ("03") over its title.
  static final EditorialTextStyle chapterNumber = _role(
    AppTextStyle.editorialSerif(
      64,
      FontWeight.w400,
      height: 1,
      letterSpacing: -1,
    ),
  );

  /// A call to action's label (Shop, Match Your Wardrobe).
  static final EditorialTextStyle cta = _role(
    _sans(14, FontWeight.w600, height: 1.3),
  );

  /// The reader's "3 / 12"; tabular, so it doesn't shift as it counts.
  static final EditorialTextStyle progressCounter = _role(
    _sans(
      12,
      FontWeight.w400,
      height: 1.2,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    secondary: true,
  );
}
