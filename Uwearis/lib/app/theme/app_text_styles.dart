import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Every `NotoSansTC` style (mirrored in [AppTheme]'s `textTheme`) carries:
///  - a `FontVariation('wght', …)` matching `fontWeight`: iOS CoreText
///    renders the variable font at its heaviest master without it.
///  - `leadingDistribution: even`: the tall CJK line box otherwise pushes
///    Latin text above centre.
class AppTextStyle {
  /// The "Uwearis" wordmark. Not `const`: [GoogleFonts.sora] loads the font
  /// at call time. Only the w700 file is bundled (assets/google_fonts/).
  static TextStyle get brandTitle => GoogleFonts.sora(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  /// [brandTitle] at AppToolBar size (Home / Explore).
  static TextStyle get brandTitleToolbar => brandTitle.copyWith(fontSize: 24);

  // ── Bold (w700) ────────────────────────────────────────────────────────

  static const TextStyle bold24 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold22 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold20 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold18 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold16 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold15 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold14 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold12 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ── Semibold (w600) ───────────────────────────────────────────────────

  static const TextStyle semibold16 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle semibold14 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ── Medium (w500) ─────────────────────────────────────────────────────

  /// AppDialog body copy and [BottomActionButton]'s label.
  static const TextStyle medium16 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle medium14 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle medium13 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  // ── Regular (w400) ────────────────────────────────────────────────────

  static const TextStyle regular16 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle regular14 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle regular13 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle regular12 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ── Role-specific ─────────────────────────────────────────────────────

  /// Small-caps field label; pair with `.toUpperCase()` on the text.
  static const TextStyle overline12 = TextStyle(
    fontFamily: 'NotoSansTC',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  /// Body text inside a `UwearisInsightCard`.
  static final TextStyle insightCardBody = regular14.copyWith(
    color: AppColors.textSecondary,
  );

  /// `ExpandableInsightBody`'s title — lighter than [bold16], which reads too
  /// heavy under the card's own bold16 header.
  static const TextStyle insightCardTitle = regular16;
}
