import 'dart:ui';

import 'package:flutter/painting.dart';

import 'app_colors.dart';

abstract class AppEffects {
  // White highlight over the top half of a glass surface (nav bar, dialog).
  static final LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.navBarGlassSheen,
      AppColors.navBarGlassSheen.withValues(alpha: 0),
    ],
    stops: const [0, 0.5],
  );

  static const LinearGradient dialogGlass = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.dialogGlassTop, AppColors.dialogGlassBottom],
  );

  static final ImageFilter dialogGlassBlur = ImageFilter.blur(
    sigmaX: 5,
    sigmaY: 5,
  );
}
