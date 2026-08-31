import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The app's standard "Close ✕" pill button — accent-tinted fill, no border,
/// bolded double-stroke X.
class CloseActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CloseActionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.accentTint,
        foregroundColor: AppColors.accent,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.close,
            style: AppTextStyle.bold16.copyWith(color: AppColors.accent),
          ),
          const SizedBox(width: 8),
          const Stack(
            children: [
              Icon(Icons.close, size: 22, color: AppColors.accent),
              Padding(
                padding: EdgeInsets.only(left: 0.6),
                child: Icon(Icons.close, size: 22, color: AppColors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
