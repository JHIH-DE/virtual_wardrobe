import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansTC',
      scaffoldBackgroundColor: AppColors.pageBackground,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            surfaceTint: Colors.transparent,
          ).copyWith(
            // fromSeed() derives a purple-hued palette from this near-black,
            // near-zero-chroma seed; pin the interactive colors so cursors,
            // focus rings, and progress indicators match the app's ink/accent
            // palette instead of that derived hue.
            primary: AppColors.primary,
            secondary: AppColors.accent,
            surface: AppColors.surface,
          ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionHandleColor: AppColors.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );

    // Two NotoSansTC quirks fixed here for every Material default (SnackBars,
    // dialogs, fields, buttons…) — AppTextStyle carries the same two itself:
    //  1. It's a variable font; iOS renders every style at the heaviest
    //     master without an explicit `wght` FontVariation.
    //  2. Its CJK line metrics are tall and top-heavy, so Latin text sits
    //     above centre in a button/chip; `even` leading splits the slack.
    return base.copyWith(
      textTheme: _normalizeFontMetrics(base.textTheme),
      primaryTextTheme: _normalizeFontMetrics(base.primaryTextTheme),
    );
  }

  static TextTheme _normalizeFontMetrics(TextTheme t) {
    TextStyle? pin(TextStyle? s) {
      if (s == null) return null;
      final numericWeight = (s.fontWeight ?? FontWeight.w400).value;
      return s.copyWith(
        fontVariations: [FontVariation('wght', numericWeight.toDouble())],
        leadingDistribution: TextLeadingDistribution.even,
      );
    }

    return TextTheme(
      displayLarge: pin(t.displayLarge),
      displayMedium: pin(t.displayMedium),
      displaySmall: pin(t.displaySmall),
      headlineLarge: pin(t.headlineLarge),
      headlineMedium: pin(t.headlineMedium),
      headlineSmall: pin(t.headlineSmall),
      titleLarge: pin(t.titleLarge),
      titleMedium: pin(t.titleMedium),
      titleSmall: pin(t.titleSmall),
      bodyLarge: pin(t.bodyLarge),
      bodyMedium: pin(t.bodyMedium),
      bodySmall: pin(t.bodySmall),
      labelLarge: pin(t.labelLarge),
      labelMedium: pin(t.labelMedium),
      labelSmall: pin(t.labelSmall),
    );
  }
}
