import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

enum DialogOptionCardVariant {
  /// Icon-left, label-right pill row.
  row,

  /// Icon circle above a centered label, for side-by-side cards.
  square,
}

/// A tappable icon+label option for "pick one of a few actions" dialogs.
class DialogOptionCard extends StatelessWidget {
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;
  final DialogOptionCardVariant variant;

  const DialogOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.variant = DialogOptionCardVariant.row,
  });

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      DialogOptionCardVariant.row => _RowCard(
        icon: icon,
        label: label,
        onTap: onTap,
      ),
      DialogOptionCardVariant.square => _SquareCard(
        icon: icon,
        label: label,
        onTap: onTap,
      ),
    };
  }
}

class _RowCard extends StatelessWidget {
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;

  const _RowCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Fill lives on the inner Material so it doesn't hide InkWell's ink.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
          BoxShadow(
            color: AppColors.shadowResting,
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: AppColors.pressedOverlay,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: label,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareCard extends StatelessWidget {
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;

  const _SquareCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: AppColors.pressedOverlay,
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final circleSize = constraints.maxWidth * 0.5;
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: const BoxDecoration(
                        color: AppColors.placeholderSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: icon),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: FittedBox(fit: BoxFit.scaleDown, child: label),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
