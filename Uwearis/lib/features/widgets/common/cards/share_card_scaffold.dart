import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Fixed-size frame for the garment / outfit share cards: photo on top,
/// [info] text stack and a Uwearis signature below.
///
/// `borderStrong`, not `borderSubtle`: the rasterized PNG has no shadow, so
/// the edge alone must separate it from a light share-sheet background.
class ShareCardScaffold extends StatelessWidget {
  final double width;
  final double height;
  final Widget image;
  final List<Widget> info;

  final double borderRadius;

  /// 1.5, not 1: a hairline curve vanishes over a garment's white product shot.
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
    // Clip inset by the border width rather than clipping to the border's
    // own curve: two anti-aliased curves at the same arc leave a notch.
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
