import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/widgets/common/overlays/error_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../config/app_config.dart';
import '../services/auth_storage.dart';
import 'debug_log.dart';

Future<void> openPrivacyPolicy(BuildContext context) =>
    _openPage(context, AppConfig.privacyPolicyUrl);

Future<void> openTermsOfService(BuildContext context) =>
    _openPage(context, AppConfig.termsOfServiceUrl);

/// In-app browser (SFSafariViewController / Custom Tabs), so the user stays
/// in the app.
Future<void> _openPage(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context);
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  } catch (e) {
    debugLog('openPage failed: $e');
  }
  if (!opened && context.mounted) {
    await showErrorDialog(context, message: l10n.openLinkFailed);
  }
}

/// Opens a pre-filled support email. The diagnostics let support find the
/// user's Crashlytics reports by user id. With no mail app, copies the
/// address instead.
Future<void> contactSupport(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final info = await PackageInfo.fromPlatform();
  final userId = await AuthStorage.getUserId();
  final body = l10n.supportEmailBody(
    '${info.version} (${info.buildNumber})',
    '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    userId ?? '-',
  );
  // Built by hand: Uri.queryParameters encodes spaces as '+', which mail
  // apps show literally.
  final uri = Uri.parse(
    'mailto:${AppConfig.supportEmail}'
    '?subject=${Uri.encodeComponent(l10n.supportEmailSubject)}'
    '&body=${Uri.encodeComponent(body)}',
  );

  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugLog('contactSupport failed: $e');
  }
  if (opened) return;

  await Clipboard.setData(const ClipboardData(text: AppConfig.supportEmail));
  if (!context.mounted) return;
  await showErrorDialog(
    context,
    title: l10n.contactSupport,
    message: l10n.supportEmailCopied(AppConfig.supportEmail),
  );
}
