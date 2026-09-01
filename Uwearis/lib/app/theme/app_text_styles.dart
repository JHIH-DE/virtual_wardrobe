import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyle {
  /// Home App Bar's "Uwearis" wordmark. Not `const`: [GoogleFonts.sora] loads/
  /// caches the font at call time rather than being a const constructor.
  static TextStyle get brandTitle => GoogleFonts.sora(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  // ── Bold (w700) ────────────────────────────────────────────────────────

  static const TextStyle bold24 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold20 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold18 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold16 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold14 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle bold12 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ── Semibold (w600) ───────────────────────────────────────────────────

  static const TextStyle semibold16 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle semibold14 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ── Medium (w500) ─────────────────────────────────────────────────────

  /// Matches AppDialog's primary button label and body copy (`regular16` +
  /// `w500`) — use for other primary call-to-action buttons or dialog-style
  /// paragraphs that should read the same, e.g. [BottomActionButton].
  static const TextStyle medium16 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle medium13 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  // ── Regular (w400) ────────────────────────────────────────────────────

  static const TextStyle regular16 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 16,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle regular14 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 14,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle regular13 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 13,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle regular12 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 12,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ── Role-specific ─────────────────────────────────────────────────────

  /// Small-caps label above a form field or card — e.g. Add Outfit's
  /// per-slot category label, Garment Details' field titles. Pair with
  /// `.toUpperCase()` on the text itself.
  static const TextStyle overline12 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );
}
