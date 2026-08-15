import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/outfit.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'outfit_image.dart';

class OutfitCard extends StatelessWidget {
  final Outfit outfit;
  final VoidCallback onTap;

  const OutfitCard({super.key, required this.outfit, required this.onTap});

  String _label(AppLocalizations l10n) {
    if (outfit.name != null && outfit.name!.isNotEmpty) return outfit.name!;
    final parts = [
      ...outfit.style,
      ...outfit.seasons,
    ].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return l10n.outfitFallbackTitle(outfit.id);
    return parts.map(_capitalize).join(' ');
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.outfitCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutfitImage(
                    imageUrl: outfit.imageUrl,
                    outfitId: outfit.id,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    noImageLabel: l10n.noImage,
                    errorLabel: l10n.failedToLoad,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Text(
                    _label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bold14.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
