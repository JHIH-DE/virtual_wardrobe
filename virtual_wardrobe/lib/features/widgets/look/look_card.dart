import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/look.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'look_image.dart';

class LookCard extends StatelessWidget {
  final Look look;
  final VoidCallback onTap;

  const LookCard({super.key, required this.look, required this.onTap});

  String _label(AppLocalizations l10n) {
    if (look.name != null && look.name!.isNotEmpty) return look.name!;
    final parts = [
      ...look.style,
      ...look.seasons,
    ].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return l10n.lookFallbackTitle(look.id);
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
        height: AppDimens.lookCardHeight,
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
                  child: LookImage(
                    imageUrl: look.imageUrl,
                    lookId: look.id,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
