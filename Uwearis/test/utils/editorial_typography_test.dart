import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/editorial_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorialTextStyle.span', () {
    test('Latin-only text is one run in the role\'s style', () {
      final span = EditorialTypography.sectionLabel.span('THE DETAILS / 03');
      expect(span.text, 'THE DETAILS / 03');
      expect(span.children, isNull);
      expect(span.style, EditorialTypography.sectionLabel.style);
    });

    test('a mixed line switches only its CJK runs, not the paragraph', () {
      final label = EditorialTypography.sectionLabel;
      final span = label.span('上衣 TOP / 03');
      expect(span.style, label.style);
      final runs = span.children!.cast<TextSpan>();
      expect(runs.map((r) => r.text), ['上衣', ' TOP / 03']);
      expect(
        runs.first.style!.letterSpacing,
        lessThan(label.style.letterSpacing!),
      );
      expect(runs.last.style, isNull);
    });

    test('a display role sets CJK in the sans and Latin in the serif', () {
      final span = EditorialTypography.quote.span('「Less」，更好。');
      final runs = span.children!.cast<TextSpan>();
      expect(runs.map((r) => r.text), ['「', 'Less', '」，更好。']);
      expect(runs.first.style!.fontFamily, 'NotoSansTC');
      expect(span.style!.fontFamily, isNot('NotoSansTC'));
    });
  });

  test('colours follow the surface: secondary roles soften on the page and '
      'on a dark page, every role is white on a photo', () {
    final caption = EditorialTypography.caption;
    final heading = EditorialTypography.pageHeading;
    expect(caption.style.color, AppColors.textSecondary);
    expect(heading.style.color, AppColors.textPrimary);
    expect(
      caption.on(EditorialSurface.image).style.color,
      AppColors.textOnPrimary,
    );
    expect(
      caption.on(EditorialSurface.dark).style.color,
      AppColors.onPhotoMuted,
    );
    expect(
      heading.on(EditorialSurface.dark).style.color,
      AppColors.textOnPrimary,
    );
  });

  test('only display roles may shrink', () {
    expect(EditorialTypography.coverTitle.minFontSize, isNotNull);
    expect(EditorialTypography.quote.minFontSize, isNotNull);
    for (final role in [
      EditorialTypography.pageHeading,
      EditorialTypography.body,
      EditorialTypography.caption,
      EditorialTypography.itemTitle,
      EditorialTypography.productName,
      EditorialTypography.productMeta,
    ]) {
      expect(role.minFontSize, isNull);
    }
  });
}
