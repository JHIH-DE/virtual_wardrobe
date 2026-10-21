import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/services/auth_handler.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../buttons/accent_pill_button.dart';

/// Renders nothing for [AuthExpiredException] — the page's auth-expiry
/// listener handles that.
class ErrorStateWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String? retryLabel;

  const ErrorStateWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (error is AuthExpiredException) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.icon),
          const SizedBox(height: 12),
          Text(
            // Never the raw exception text.
            AppLocalizations.of(context).failedToLoad,
            style: AppTextStyle.regular16.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          AccentPillButton(
            label: retryLabel ?? AppLocalizations.of(context).retry,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
