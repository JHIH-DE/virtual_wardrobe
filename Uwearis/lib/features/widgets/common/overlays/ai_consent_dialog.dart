import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/ai_consent.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// True once the user has agreed to AI processing — asking first if they
/// haven't. Call it in every handler that sends data to the AI service (or
/// opens a screen whose load does), before any request or loading overlay;
/// on false, send nothing. Concurrent calls share one dialog, so it may run
/// ahead of a handler's re-entrancy guard (re-check the guard after it).
Future<bool> ensureAiConsent(BuildContext context) {
  return _pending ??= _ask(context).whenComplete(() => _pending = null);
}

Future<bool>? _pending;

Future<bool> _ask(BuildContext context) async {
  if (await AiConsent.isGranted()) return true;
  if (!context.mounted) return false;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (_) => const _AiConsentDialog(),
  );
  if (agreed != true) return false;
  await AiConsent.grant();
  return true;
}

class _AiConsentDialog extends StatelessWidget {
  const _AiConsentDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.aiConsentTitle,
      // Left-aligned, unlike other dialogs' centered text: a centered
      // paragraph this long is hard to read.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aiConsentBody(AppConfig.aiProviderName),
            style: AppTextStyle.medium16,
          ),
          Center(
            child: TextButton(
              onPressed: () => openPrivacyPolicy(context),
              child: Text(
                l10n.privacyPolicy,
                style: AppTextStyle.medium14.copyWith(
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
      primaryLabel: l10n.aiConsentAgree,
      onPrimary: () => Navigator.of(context).pop(true),
      secondaryLabel: l10n.aiConsentDecline,
      onSecondary: () => Navigator.of(context).pop(false),
      secondaryIsTextButton: true,
    );
  }
}
