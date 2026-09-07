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

    // NotoSansTC is a variable font; iOS needs an explicit `wght` FontVariation
    // or it renders every Material default (SnackBars, dialogs, fields…) at the
    // heaviest master. AppTextStyle carries its own; this covers the rest.
    return base.copyWith(
      textTheme: _pinVariableWeight(base.textTheme),
      primaryTextTheme: _pinVariableWeight(base.primaryTextTheme),
    );
  }

  static TextTheme _pinVariableWeight(TextTheme t) {
    TextStyle? pin(TextStyle? s) {
      if (s == null) return null;
      final numericWeight = (s.fontWeight ?? FontWeight.w400).value;
      return s.copyWith(
        fontVariations: [FontVariation('wght', numericWeight.toDouble())],
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
