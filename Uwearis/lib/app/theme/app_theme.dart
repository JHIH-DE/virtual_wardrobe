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
            // fromSeed() derives a purple hue from this near-black seed; pin
            // the interactive colors to the app palette.
            primary: AppColors.primary,
            secondary: AppColors.accent,
            surface: AppColors.surface,
          ),
      // Matches AppTextField's focused border.
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.textSecondary,
        selectionHandleColor: AppColors.textSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );

    // NotoSansTC quirks, fixed for Material defaults as AppTextStyle does:
    //  1. Variable font: iOS renders the heaviest master without an
    //     explicit `wght` FontVariation.
    //  2. Tall CJK metrics push Latin text above centre; `even` leading
    //     splits the slack.
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
