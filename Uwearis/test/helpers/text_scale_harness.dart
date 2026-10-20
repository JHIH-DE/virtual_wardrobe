import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/adaptive_side_layout.dart';

/// Loads the bundled NotoSansTC so layout tests measure real glyph widths;
/// the default test font (Ahem) draws every glyph as a 1em square, which
/// over-reports Latin widths and under-reports nothing.
Future<void> loadAppFont() async {
  final loader = FontLoader('NotoSansTC')
    ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
  await loader.load();
}

/// One screen configuration a text-scale layout test runs under.
typedef LayoutCase = ({double width, double scale, Locale locale});

/// 390 = a current iPhone; 320 = the narrowest phone width still in use
/// (iPhone SE 1st gen / small Android), the strictest case.
final List<LayoutCase> layoutCases = [
  for (final width in [390.0, 320.0])
    for (final scale in [1.0, 1.3, 2.0])
      for (final locale in [Locale('en'), Locale('zh', 'TW')])
        (width: width, scale: scale, locale: locale),
];

String describeCase(LayoutCase c) =>
    '${c.width.toInt()}pt · ${c.scale}× · ${c.locale.toLanguageTag()}';

/// Applies [c] to the test view and platform; everything is reset on
/// teardown. [height] defaults to a phone; pass a tall one to lay out a
/// whole scrolling page at once.
void applyLayoutCase(WidgetTester tester, LayoutCase c, {double height = 844}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(c.width * 3, height * 3);
  tester.platformDispatcher.textScaleFactorTestValue = c.scale;
  tester.platformDispatcher.localesTestValue = [c.locale];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text);

/// How many lines [text] (a `find.text`/`find.byType(Text)` finder for one
/// Text) actually rendered on.
int renderedLineCount(WidgetTester tester, Finder text) {
  final paragraph = _paragraph(tester, text);
  final length = paragraph.text.toPlainText().length;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  return boxes.map((b) => b.top.round()).toSet().length;
}

/// The text hit its `maxLines` and was cut (ellipsized or clipped).
bool isTruncated(WidgetTester tester, Finder text) =>
    _paragraph(tester, text).didExceedMaxLines;

/// [inner] paints entirely within [outer]'s bounds — nothing is pushed out
/// of, or hidden under the edge of, its container.
void expectWithin(WidgetTester tester, Finder inner, Finder outer) {
  final i = tester.getRect(inner);
  final o = tester.getRect(outer);
  const slack = 0.5;
  expect(
    i.left >= o.left - slack &&
        i.top >= o.top - slack &&
        i.right <= o.right + slack &&
        i.bottom <= o.bottom + slack,
    isTrue,
    reason: '$i is not inside $o',
  );
}

/// No Latin word of [text] is split across lines: its widest word fits the
/// width it was given. CJK wraps between any two characters, so it's exempt
/// (and `getMinIntrinsicWidth` can't be used: it treats a CJK run as one
/// word).
void expectNoBrokenWords(WidgetTester tester, Finder text) {
  final paragraph = _paragraph(tester, text);
  expect(
    longestWordWidth(paragraph),
    lessThanOrEqualTo(paragraph.constraints.maxWidth + 0.5),
    reason: '"${paragraph.text.toPlainText()}" breaks inside a word',
  );
}
