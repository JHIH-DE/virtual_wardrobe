import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_effects.dart';

/// The translucent frosted-glass surface behind [AppDialog] and
/// [showFeedbackOverlay].
class DialogGlassPanel extends StatelessWidget {
  const DialogGlassPanel({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: AppEffects.dialogGlassBlur,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: AppEffects.dialogGlass,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppEffects.glassSheen),
            child: child,
          ),
        ),
      ),
    );
  }
}
