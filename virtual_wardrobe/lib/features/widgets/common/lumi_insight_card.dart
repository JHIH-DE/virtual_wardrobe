import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Call-out reserved for LUMI's AI-generated text output (packing advice,
/// styling tips, etc.) so users can tell "the AI said this" at a glance: a
/// soft gradient card, a circular sparkle badge, and an "AI" tag next to
/// the LUMI wordmark. [child] is the body content below that header — a
/// plain [Text], a loading row, a collapsible section, etc.
class LumiInsightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const LumiInsightCard({super.key, required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.lumiCardTint],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.textOnPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.appTitle,
                style: AppTextStyle.bold16.copyWith(letterSpacing: 1.5),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.aiTag,
                  style: AppTextStyle.bold12.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
