import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Shared frame for the share cards (garment / outfit): a fixed-size,
/// bordered card with a flexible photo on top and a [AppColors.pageBackground]
/// info block below, closed by a hairline and a small Uwearis signature. The
/// `borderStrong` edge is what keeps the rasterized PNG from bleeding
/// invisibly into a light chat/share-sheet background — this card has no
/// drop shadow of its own (it's captured flat, not rendered on a page) to
/// lean on instead, and `borderSubtle` (used for hairlines elsewhere) reads
/// as barely-there against a white product-shot photo, so this needs the
/// stronger token to actually trace the rounded corner over white.
///
/// [image] is supplied by the caller so each card decides its own photo
/// treatment (a lifestyle render bleeds edge-to-edge with `cover`; a garment
/// product shot sits `contain` on white). [info] is the editorial text
/// stack — name, meta lines — above the signature.
class ShareCardScaffold extends StatelessWidget {
  final double width;
  final double height;
  final Widget image;
  final List<Widget> info;

  /// Corner radius of the card. Defaults to [AppDimens.cardRadius]; pass 0
  /// for a hard-edged card.
  final double borderRadius;

  /// 1.5px, not the 1px default — over a garment card's white product shot
  /// (`BoxFit.contain` on `AppColors.surface`) a hairline-width curve is
  /// nearly imperceptible against the equally-white sheet behind it; the
  /// outfit card's photo never has this problem (a lifestyle photo is
  /// rarely plain white to the edges), but one shared scaffold means one
  /// width that has to read clearly on both.
  static const double _borderWidth = 1.5;

  const ShareCardScaffold({
    super.key,
    required this.width,
    required this.height,
    required this.image,
    required this.info,
    this.borderRadius = AppDimens.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    // The border and the content clip are deliberately two separate
    // `Radius`-bearing layers, inset from each other by exactly the
    // border's own width (see `Padding` below) — relying on a single
    // Container's clipBehavior to also bound an edge-to-edge opaque child
    // (the photo) leaves the border's rounded corner painted *underneath*
    // that child, since it's clipped to the same outer curve; Skia's
    // anti-aliasing then doesn't perfectly reconcile the two independently
    // drawn curves right at the arc, showing as a small notch at each
    // corner instead of a clean edge — a straight edge has no such seam.
    final innerRadius = (borderRadius - _borderWidth).clamp(
      0.0,
      double.infinity,
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.borderStrong, width: _borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: Padding(
          padding: const EdgeInsets.all(_borderWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The photo flexes to fill whatever the info block doesn't
              // take, so the card stays a fixed size with no dead space.
              Expanded(child: image),
              Container(
                color: AppColors.pageBackground,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...info,
                    const SizedBox(height: 16),
                    Container(height: 1, color: AppColors.borderSubtle),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 11,
                          color: AppColors.hintText,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Uwearis',
                          style: AppTextStyle.brandTitle.copyWith(
                            fontSize: 13,
                            letterSpacing: 0.2,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A meta line that scales down to fit rather than truncating — the share
/// cards never show "…" on style / category / detail lines.
Widget shareCardShrinkLine(String text, TextStyle style) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(text, maxLines: 1, softWrap: false, style: style),
  );
}
