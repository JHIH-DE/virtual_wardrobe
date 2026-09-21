import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// [DialogOptionCard]'s two visual treatments — see the class doc for when
/// each applies. Add a new variant here rather than a second widget if a
/// third shape is ever needed for the same "pick one of a few actions"
/// concept.
enum DialogOptionCardVariant {
  /// Icon-left, label-right pill row — the original/default shape.
  row,

  /// Icon-in-a-circle above a centered label, meant to sit side by side
  /// with another square card (e.g. Camera / Album) rather than stacked.
  square,
}

/// A tappable icon+label option inside an [AppDialog]'s custom `content` —
/// the shared shape behind every "pick one of a few actions" dialog
/// (`GarmentUploadHelper`'s Take Photo/Choose from Album, `SharedMediaHandler`'s
/// Add Clothing/Match a Look). Reuse this — with [variant] for a different
/// layout — rather than a second copy.
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
      DialogOptionCardVariant.row => _RowCard(icon: icon, label: label, onTap: onTap),
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

  const _RowCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Shadow on a plain container; the fill + ink on a Material inside it,
    // so InkWell's pressed highlight actually shows (an opaque Container on
    // top of the ink would hide it).
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
                  // scaleDown so a longer label (or wider glyph metrics on
                  // iOS's bundled font) shrinks to fit rather than
                  // overflowing the row.
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

  const _SquareCard({required this.icon, required this.label, required this.onTap});

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
          // The icon circle is sized off the card's own (LayoutBuilder)
          // width rather than a fixed constant, so this never overflows a
          // narrower card — a dialog width the caller controls, and two of
          // these sit side by side.
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
