import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Shared frame for the share cards (garment / outfit): a fixed-size,
/// transparent-cornered card with a flexible photo on top and a
/// [AppColors.pageBackground] info block below, closed by a hairline and a
/// small Uwearis signature.
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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The photo flexes to fill whatever the info block doesn't take,
          // so the card stays a fixed size with no dead space.
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
